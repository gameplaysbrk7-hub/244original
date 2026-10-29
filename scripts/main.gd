extends Node3D
## Cena principal da Fase 1: monta a pista, a moto, a câmera e a interface.

const Motorcycle := preload("res://scripts/vehicle/motorcycle.gd")
const FollowCamera := preload("res://scripts/camera/follow_camera.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const CityBuilder := preload("res://scripts/city/city_builder.gd")
const TrafficManager := preload("res://scripts/traffic/traffic_manager.gd")
const SettingsStore := preload("res://scripts/save/settings_store.gd")

var bike: Motorcycle
var cam: FollowCamera
var touch: TouchControls
var hud: Hud
var traffic: TrafficManager
var city_info: Dictionary = {}
var settings  # autoload GameSettings (ou instância local se não existir)


func _ready() -> void:
	settings = get_node_or_null("/root/GameSettings")
	if settings == null:
		settings = SettingsStore.new()
		settings.name = "LocalSettings"
		add_child(settings)

	city_info = CityBuilder.build(self)

	bike = Motorcycle.new()
	bike.name = "Motorcycle"
	bike.position = city_info["spawn"]
	add_child(bike)

	cam = FollowCamera.new()
	cam.name = "FollowCamera"
	add_child(cam)
	cam.target = bike
	cam.distance = settings.camera_distance
	cam.pitch_deg = settings.camera_pitch
	cam.yaw_offset = settings.camera_yaw_offset
	cam.first_person = settings.camera_first_person
	cam.snap()

	var ui := CanvasLayer.new()
	ui.layer = 10
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	touch = TouchControls.new()
	touch.ui_opacity = settings.control_opacity
	touch.steer_sensitivity = settings.steer_sensitivity
	ui.add_child(touch)
	hud = Hud.new()
	add_child(hud)

	traffic = TrafficManager.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(city_info["roads"], bike, settings.traffic_density)
	hud.setup_minimap(bike, city_info, traffic)

	touch.camera_drag.connect(cam.orbit)
	touch.camera_zoom.connect(cam.zoom)
	touch.camera_drag_ended.connect(_save_camera)
	touch.camera_reset_pressed.connect(_reset_camera)
	touch.respawn_pressed.connect(bike.respawn)
	touch.pause_pressed.connect(_toggle_pause)
	touch.view_toggle_pressed.connect(_toggle_view)
	bike.stoppie_finished.connect(hud.show_stoppie_result)
	bike.wheelie_finished.connect(hud.show_wheelie_result)
	bike.crashed.connect(hud.show_message.bind("QUEDA!"))


func _physics_process(_delta: float) -> void:
	var kb_thr := 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
	var kb_steer := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb_steer += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb_steer -= 1.0
	bike.input_throttle = maxf(touch.throttle, kb_thr)
	bike.input_brake_front = 1.0 if (touch.brake_front or Input.is_key_pressed(KEY_SHIFT)) else 0.0
	bike.input_brake_rear = 1.0 if (touch.brake_rear or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
	bike.input_steer = touch.steer if absf(touch.steer) > 0.01 else kb_steer
	bike.input_wheelie = touch.wheelie or Input.is_key_pressed(KEY_SPACE)
	bike.input_balance = touch.balance or Input.is_key_pressed(KEY_B)
	bike.input_drift = touch.drift or Input.is_key_pressed(KEY_X)
	cam.view_pitch = bike.pitch - bike.stoppie


func _process(_delta: float) -> void:
	hud.update_hud(bike)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_R:
				bike.respawn()
			KEY_C:
				_reset_camera()
			KEY_V:
				_toggle_view()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	hud.set_paused(get_tree().paused)
	_save_camera()


func _toggle_view() -> void:
	cam.toggle_view()
	_save_camera()


func _reset_camera() -> void:
	cam.reset_view()
	_save_camera()


func _save_camera() -> void:
	settings.camera_distance = cam.distance
	settings.camera_pitch = cam.pitch_deg
	settings.camera_yaw_offset = cam.yaw_offset
	settings.camera_first_person = cam.first_person
	settings.save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if cam != null and settings != null:
			_save_camera()
