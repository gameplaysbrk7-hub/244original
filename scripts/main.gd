extends Node3D
## Cena principal: monta a cidade, a moto, a câmera, o trânsito, as missões e os menus,
## e controla o fluxo entre tela inicial, jogo, pausa e garagem.

const Motorcycle := preload("res://scripts/vehicle/motorcycle.gd")
const FollowCamera := preload("res://scripts/camera/follow_camera.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const CityBuilder := preload("res://scripts/city/city_builder.gd")
const TrafficManager := preload("res://scripts/traffic/traffic_manager.gd")
const SettingsStore := preload("res://scripts/save/settings_store.gd")
const GameState := preload("res://scripts/save/game_state.gd")
const BikeCatalog := preload("res://scripts/vehicle/bike_catalog.gd")
const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const MissionManager := preload("res://scripts/missions/mission_manager.gd")
const MenuUi := preload("res://scripts/ui/menu_ui.gd")
const GarageUi := preload("res://scripts/ui/garage_ui.gd")

enum Mode { MENU, PLAYING, PAUSED, GARAGE }

var bike: Motorcycle
var cam: FollowCamera
var touch: TouchControls
var hud: Hud
var traffic: TrafficManager
var missions: MissionManager
var menu: MenuUi
var garage: GarageUi
var state: GameState
var city_info: Dictionary = {}
var settings  # autoload GameSettings (ou instância local se não existir)
var mode: int = Mode.MENU

var _return_mode: int = Mode.MENU
var _garage_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	settings = get_node_or_null("/root/GameSettings")
	if settings == null:
		settings = SettingsStore.new()
		settings.name = "LocalSettings"
		add_child(settings)

	state = GameState.new()
	state.name = "GameState"
	add_child(state)
	state.load_game()

	city_info = CityBuilder.build(self)
	for p in city_info["pois"]:
		if p["id"] == "garagem":
			_garage_pos = p["pos"]

	bike = Motorcycle.new()
	bike.name = "Motorcycle"
	bike.position = city_info["spawn"]
	var prof := BikeCatalog.load_profile(state.selected_bike)
	bike.profile = prof
	bike.custom = state.get_custom(state.selected_bike, BikeModel.default_custom(prof))
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

	missions = MissionManager.new()
	missions.name = "Missions"
	add_child(missions)
	missions.setup(state, bike, city_info["pois"])
	hud.setup_minimap(bike, city_info, traffic, missions)
	hud.set_money(state.money)

	var menus := CanvasLayer.new()
	menus.layer = 20
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menus)
	menu = MenuUi.new()
	menu.state = state
	menu.missions = missions
	menu.settings = settings
	menus.add_child(menu)
	garage = GarageUi.new()
	garage.state = state
	garage.bike = bike
	menus.add_child(garage)

	touch.camera_drag.connect(cam.orbit)
	touch.camera_zoom.connect(cam.zoom)
	touch.camera_drag_ended.connect(_save_camera)
	touch.camera_reset_pressed.connect(_reset_camera)
	touch.respawn_pressed.connect(bike.respawn)
	touch.pause_pressed.connect(_pause)
	touch.view_toggle_pressed.connect(_toggle_view)
	bike.wheelie_finished.connect(hud.show_wheelie_result)
	bike.stoppie_finished.connect(hud.show_stoppie_result)
	bike.crashed.connect(hud.show_message.bind("QUEDA!"))
	state.money_changed.connect(hud.set_money)
	missions.started.connect(_on_mission_started)
	missions.completed.connect(_on_mission_completed)
	missions.failed.connect(_on_mission_failed)
	menu.play_pressed.connect(_start_playing)
	menu.resume_pressed.connect(_start_playing)
	menu.garage_pressed.connect(_open_garage)
	menu.restart_pressed.connect(_restart)
	menu.to_title_pressed.connect(_to_title)
	menu.quit_pressed.connect(_quit)
	menu.mission_start_requested.connect(_start_mission)
	menu.mission_cancel_requested.connect(_cancel_mission)
	menu.settings_changed.connect(_apply_settings)
	garage.closed.connect(_close_garage)
	garage.orbit_requested.connect(cam.orbit)

	_enter_menu()


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
	hud.set_objective(missions.objective_text())


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
			KEY_ESCAPE:
				_pause()


# ------------------------------------------------------------- fluxo de telas

func _touch_enabled(on: bool) -> void:
	touch.visible = on
	touch.set_process_input(on)
	if not on:
		touch._release_all()
		touch.throttle = 0.0


func _enter_menu() -> void:
	mode = Mode.MENU
	get_tree().paused = true
	cam.showroom = true
	_touch_enabled(false)
	garage.close()
	menu.in_game = false
	menu.open("title")


func _start_playing() -> void:
	mode = Mode.PLAYING
	get_tree().paused = false
	cam.showroom = false
	cam.snap()
	menu.close()
	garage.close()
	_touch_enabled(true)


func _pause() -> void:
	if mode != Mode.PLAYING:
		return
	mode = Mode.PAUSED
	get_tree().paused = true
	_touch_enabled(false)
	_save_camera()
	menu.in_game = true
	menu.open("pause")


func _restart() -> void:
	missions.cancel()
	bike.respawn()
	_start_playing()


func _to_title() -> void:
	missions.cancel()
	bike.respawn()
	state.save_game()
	_enter_menu()


func _quit() -> void:
	state.save_game()
	get_tree().quit()


func _open_garage() -> void:
	if mode == Mode.PAUSED and bike.global_position.distance_to(_garage_pos) > 28.0:
		menu.set_status("Vá até a GARAGEM (marcador G no minimapa).")
		return
	_return_mode = mode
	mode = Mode.GARAGE
	menu.close()
	cam.showroom = true
	garage.open()


func _close_garage() -> void:
	mode = _return_mode
	if mode == Mode.MENU:
		menu.open("title")
	else:
		cam.showroom = false
		cam.snap()
		menu.open("pause")


# ------------------------------------------------------------------- missões

func _start_mission(id: String) -> void:
	if missions.start(id):
		_start_playing()
	else:
		menu.set_status("Não foi possível iniciar a missão.")


func _cancel_mission() -> void:
	missions.cancel()
	menu.open("missions")


func _on_mission_started(m: Dictionary) -> void:
	hud.show_message("MISSÃO: " + str(m["title"]))


func _on_mission_completed(_m: Dictionary, reward: int) -> void:
	hud.show_message("MISSÃO COMPLETA!  +" + GameState.format_money(reward))


func _on_mission_failed(_m: Dictionary, reason: String) -> void:
	hud.show_message("MISSÃO FALHOU: " + reason)


# --------------------------------------------------------------- configurações

func _apply_settings() -> void:
	touch.steer_sensitivity = settings.steer_sensitivity
	touch.ui_opacity = settings.control_opacity
	traffic.set_density(settings.traffic_density)
	settings.save_settings()


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
		if state != null:
			state.save_game()
