extends Resource
## Parâmetros de uma motocicleta. Cada moto futura será um .tres deste tipo.

@export var display_name: String = "Zangão 125"
@export var max_speed: float = 38.0            # m/s (~137 km/h)
@export var accel: float = 9.0                 # m/s² com acelerador total
@export var brake_front: float = 24.0          # m/s²
@export var brake_rear: float = 14.0           # m/s²
@export var rolling_resistance: float = 0.8    # m/s²
@export var air_drag: float = 0.035            # 1/s (resistência linear simplificada)
@export var steer_rate: float = 2.4            # rad/s de guinada máxima
@export var steer_falloff: float = 0.045       # reduz a direção em alta velocidade
@export var max_lean: float = 0.65             # rad de inclinação visual em curva
@export var wheelie_lift: float = 7.5          # rad/s² de torque de empinar
@export var wheelie_gravity: float = 10.0      # rad/s² de torque restaurador
@export var wheelie_max_pitch: float = 1.3     # rad: acima disso a moto cai para trás
@export var crash_speed_loss: float = 13.0     # m/s de impacto frontal que derruba
@export var body_color: Color = Color(0.85, 0.12, 0.1)
