extends Node
## Configurações persistentes (câmera e controles).
## Tolera arquivo ausente ou corrompido: nesse caso mantém os valores padrão.

const PATH := "user://settings.cfg"

var camera_distance: float = 4.6
var camera_pitch: float = 18.0
var camera_yaw_offset: float = 0.0
var camera_first_person: bool = false
var steer_sensitivity: float = 1.0
var control_opacity: float = 0.55
var traffic_density: int = 10
var volume_master: float = 1.0
var volume_sfx: float = 0.9
var volume_ambient: float = 0.6
var quality: int = 0                # 0 automática, 1 baixa, 2 média, 3 alta
var day_minutes: float = 8.0        # minutos reais por dia (0 = tempo parado)
var time_of_day: float = 9.0
var control_offsets: Dictionary = {}  # id do botão -> Vector2 (fração da tela)


func _ready() -> void:
	load_settings()


func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	camera_distance = clampf(_num(cfg, "camera", "distance", camera_distance), 2.5, 9.0)
	camera_pitch = clampf(_num(cfg, "camera", "pitch", camera_pitch), 5.0, 60.0)
	camera_yaw_offset = clampf(_num(cfg, "camera", "yaw_offset", camera_yaw_offset), -TAU, TAU)
	var fp: Variant = cfg.get_value("camera", "first_person", false)
	camera_first_person = fp if typeof(fp) == TYPE_BOOL else false
	steer_sensitivity = clampf(_num(cfg, "controls", "steer_sensitivity", steer_sensitivity), 0.4, 2.0)
	control_opacity = clampf(_num(cfg, "controls", "opacity", control_opacity), 0.15, 1.0)
	traffic_density = clampi(int(_num(cfg, "game", "traffic_density", float(traffic_density))), 0, 30)
	volume_master = clampf(_num(cfg, "audio", "master", volume_master), 0.0, 1.0)
	volume_sfx = clampf(_num(cfg, "audio", "sfx", volume_sfx), 0.0, 1.0)
	volume_ambient = clampf(_num(cfg, "audio", "ambient", volume_ambient), 0.0, 1.0)
	quality = clampi(int(_num(cfg, "graphics", "quality", float(quality))), 0, 3)
	day_minutes = clampf(_num(cfg, "game", "day_minutes", day_minutes), 0.0, 30.0)
	time_of_day = fposmod(_num(cfg, "game", "time_of_day", time_of_day), 24.0)
	control_offsets = {}
	if cfg.has_section("layout"):
		for key in cfg.get_section_keys("layout"):
			var v: Variant = cfg.get_value("layout", key)
			if typeof(v) == TYPE_VECTOR2:
				control_offsets[key] = Vector2(clampf(v.x, -0.6, 0.6), clampf(v.y, -0.6, 0.6))
	return true


func save_settings() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("camera", "distance", camera_distance)
	cfg.set_value("camera", "pitch", camera_pitch)
	cfg.set_value("camera", "yaw_offset", camera_yaw_offset)
	cfg.set_value("camera", "first_person", camera_first_person)
	cfg.set_value("controls", "steer_sensitivity", steer_sensitivity)
	cfg.set_value("controls", "opacity", control_opacity)
	cfg.set_value("game", "traffic_density", traffic_density)
	cfg.set_value("audio", "master", volume_master)
	cfg.set_value("audio", "sfx", volume_sfx)
	cfg.set_value("audio", "ambient", volume_ambient)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("game", "day_minutes", day_minutes)
	cfg.set_value("game", "time_of_day", time_of_day)
	for key in control_offsets:
		cfg.set_value("layout", str(key), control_offsets[key])
	return cfg.save(PATH) == OK


static func _num(cfg: ConfigFile, section: String, key: String, fallback: float) -> float:
	var v: Variant = cfg.get_value(section, key, fallback)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		return float(v)
	return fallback
