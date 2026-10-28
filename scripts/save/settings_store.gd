extends Node
## Configurações persistentes (câmera e controles).
## Tolera arquivo ausente ou corrompido: nesse caso mantém os valores padrão.

const PATH := "user://settings.cfg"

var camera_distance: float = 4.6
var camera_pitch: float = 18.0
var camera_yaw_offset: float = 0.0
var steer_sensitivity: float = 1.0
var control_opacity: float = 0.55


func _ready() -> void:
	load_settings()


func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	camera_distance = clampf(_num(cfg, "camera", "distance", camera_distance), 2.5, 9.0)
	camera_pitch = clampf(_num(cfg, "camera", "pitch", camera_pitch), 5.0, 60.0)
	camera_yaw_offset = clampf(_num(cfg, "camera", "yaw_offset", camera_yaw_offset), -TAU, TAU)
	steer_sensitivity = clampf(_num(cfg, "controls", "steer_sensitivity", steer_sensitivity), 0.4, 2.0)
	control_opacity = clampf(_num(cfg, "controls", "opacity", control_opacity), 0.15, 1.0)
	return true


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "distance", camera_distance)
	cfg.set_value("camera", "pitch", camera_pitch)
	cfg.set_value("camera", "yaw_offset", camera_yaw_offset)
	cfg.set_value("controls", "steer_sensitivity", steer_sensitivity)
	cfg.set_value("controls", "opacity", control_opacity)
	return cfg.save(PATH) == OK


static func _num(cfg: ConfigFile, section: String, key: String, fallback: float) -> float:
	var v: Variant = cfg.get_value(section, key, fallback)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback
