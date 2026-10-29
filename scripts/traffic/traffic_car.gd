extends AnimatableBody3D
## Carro de trânsito: apenas guarda o estado; a lógica fica no TrafficManager.

var speed: float = 0.0
var yaw: float = 0.0
var a: Vector3 = Vector3.ZERO   # início da faixa atual
var b: Vector3 = Vector3.ZERO   # fim da faixa atual
var from_node: int = 0
var to_node: int = 0
var blocked_time: float = 0.0
