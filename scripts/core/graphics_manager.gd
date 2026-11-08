extends Node
## Qualidade gráfica em 3 níveis (0 baixa, 1 média, 2 alta), mais ajustes do jogador
## (resolução, distância de renderização, sombras e efeitos visuais) e limite de FPS.

const NAMES := ["Baixa", "Média", "Alta"]

var level: int = 2
var render_scale: float = 0.0   # 0 = pelo nível de qualidade
var view_distance: int = 0      # 0 = pelo nível de qualidade
var shadows: int = 0            # 0 automático, 1 desligadas, 2 ligadas
var effects: bool = true        # névoa, fumaça dos pneus e luzes de poste

var _sun: DirectionalLight3D
var _camera: Camera3D
var _traffic: Node
var _day: Node
var _viewport: Viewport
var _env: Environment
var _bike: Node3D


func setup(sun: DirectionalLight3D, camera: Camera3D, traffic: Node, day: Node, viewport: Viewport, env: Environment = null, bike: Node3D = null) -> void:
	_sun = sun
	_camera = camera
	_traffic = traffic
	_day = day
	_viewport = viewport
	_env = env
	_bike = bike
	Engine.max_fps = 60


func configure(scale: float, distance: int, shadow_mode: int, fx: bool) -> void:
	render_scale = scale
	view_distance = distance
	shadows = shadow_mode
	effects = fx


static func level_for_setting(setting: int) -> int:
	# 0 automática, 1 baixa, 2 média, 3 alta
	if setting <= 0:
		return 1 if OS.get_processor_count() <= 4 else 2
	return clampi(setting - 1, 0, 2)


func apply(new_level: int) -> void:
	level = clampi(new_level, 0, 2)
	match level:
		0:
			_sun.shadow_enabled = false
			_camera.far = 110.0
			_viewport.scaling_3d_scale = 0.7
			_traffic.active_range = 70.0
			_day.use_lamp_lights = false
		1:
			_sun.shadow_enabled = true
			_sun.directional_shadow_max_distance = 35.0
			_camera.far = 180.0
			_viewport.scaling_3d_scale = 0.85
			_traffic.active_range = 90.0
			_day.use_lamp_lights = true
		_:
			_sun.shadow_enabled = true
			_sun.directional_shadow_max_distance = 60.0
			_camera.far = 280.0
			_viewport.scaling_3d_scale = 1.0
			_traffic.active_range = 110.0
			_day.use_lamp_lights = true
	# Ajustes do jogador por cima do nível
	if render_scale > 0.0:
		_viewport.scaling_3d_scale = render_scale
	if view_distance > 0:
		_camera.far = float(view_distance)
	if shadows == 1:
		_sun.shadow_enabled = false
	elif shadows == 2:
		_sun.shadow_enabled = true
	if _env != null:
		_env.fog_enabled = effects
	if not effects:
		_day.use_lamp_lights = false
	if _bike != null:
		_bike.effects_enabled = effects


## Teto de carros por nível de qualidade (protege celulares fracos).
func traffic_cap() -> int:
	return [8, 16, 30][level]
