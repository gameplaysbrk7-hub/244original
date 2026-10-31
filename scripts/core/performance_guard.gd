extends Node
## Observa o FPS e reduz a qualidade gráfica (nunca aumenta) se o jogo ficar lento.

signal quality_reduced(new_level: int)

const LOW_FPS := 24.0
const WINDOW := 3.0

var graphics: Node
var enabled: bool = true
var warmup: float = 6.0

var _time: float = 0.0
var _frames: int = 0
var _low_windows: int = 0


## Reinicia a medição (chamar ao voltar de menus, quando o jogo normalmente engasga).
func rearm() -> void:
	warmup = 6.0
	_time = 0.0
	_frames = 0
	_low_windows = 0


func _process(delta: float) -> void:
	if not enabled:
		return
	if warmup > 0.0:
		warmup -= delta
		return
	_time += delta
	_frames += 1
	if _time >= WINDOW:
		evaluate(_frames / _time)
		_time = 0.0
		_frames = 0


func evaluate(avg_fps: float) -> void:
	if avg_fps < LOW_FPS:
		_low_windows += 1
	else:
		_low_windows = 0
	if _low_windows >= 2 and graphics.level > 0:
		_low_windows = 0
		graphics.apply(graphics.level - 1)
		quality_reduced.emit(graphics.level)
