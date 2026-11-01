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
const Kit := preload("res://scripts/ui/ui_kit.gd")
const AudioManager := preload("res://scripts/audio/audio_manager.gd")
const DayNight := preload("res://scripts/city/day_night.gd")
const GraphicsManager := preload("res://scripts/core/graphics_manager.gd")
const PerformanceGuard := preload("res://scripts/core/performance_guard.gd")
const Pedestrian := preload("res://scripts/player/pedestrian.gd")

enum Mode { MENU, PLAYING, PAUSED, GARAGE }

const TRIGGER_RADIUS := 4.5   # distância ao acionador para o botão de interação aparecer

var bike: Motorcycle
var cam: FollowCamera
var touch: TouchControls
var hud: Hud
var traffic: TrafficManager
var missions: MissionManager
var menu: MenuUi
var garage: GarageUi
var audio: AudioManager
var day: DayNight
var gfx: GraphicsManager
var guard: PerformanceGuard
var ped: Pedestrian
var on_foot: bool = false
var state: GameState
var city_info: Dictionary = {}
var settings  # autoload GameSettings (ou instância local se não existir)
var mode: int = Mode.MENU

var _return_mode: int = Mode.MENU
var _garage_pos: Vector3 = Vector3.ZERO
var _edit_bar: VBoxContainer
var _interaction: Dictionary = {}


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
	ped = Pedestrian.new()
	ped.name = "Pedestrian"
	ped.visible = false
	add_child(ped)
	traffic.obstacles = [bike, ped]
	hud.setup_minimap(bike, city_info, traffic, missions)
	hud.set_money(state.money)

	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	audio.bike = bike
	audio.apply_volumes(settings.volume_master, settings.volume_sfx, settings.volume_ambient)
	Kit.on_click = audio.play_click

	day = DayNight.new()
	day.name = "DayNight"
	add_child(day)
	day.time_of_day = settings.time_of_day
	day.day_minutes = settings.day_minutes
	day.setup(city_info["env"], city_info["sky"], city_info["sun"], city_info["lit_materials"], city_info["lamps"], bike)

	gfx = GraphicsManager.new()
	gfx.name = "Graphics"
	add_child(gfx)
	gfx.setup(city_info["sun"], cam.camera, traffic, day, get_viewport())
	gfx.apply(GraphicsManager.level_for_setting(settings.quality))
	traffic.set_density(mini(settings.traffic_density, gfx.traffic_cap()))
	guard = PerformanceGuard.new()
	guard.name = "PerformanceGuard"
	add_child(guard)
	guard.graphics = gfx
	guard.enabled = settings.quality == 0
	guard.quality_reduced.connect(_on_quality_reduced)
	touch.offsets = settings.control_offsets.duplicate()

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
	_build_edit_bar(menus)

	touch.camera_drag.connect(cam.orbit)
	touch.camera_zoom.connect(cam.zoom)
	touch.camera_drag_ended.connect(_save_camera)
	touch.camera_reset_pressed.connect(_reset_camera)
	touch.respawn_pressed.connect(_on_respawn_pressed)
	touch.mount_pressed.connect(_on_mount_pressed)
	touch.interact_pressed.connect(_on_interact_pressed)
	ped.stepped.connect(audio.play_step)
	ped.mount_finished.connect(_finish_mount)
	ped.lift_finished.connect(_finish_lift)
	bike.crashed.connect(_on_bike_crashed)
	touch.pause_pressed.connect(_pause)
	touch.view_toggle_pressed.connect(_toggle_view)
	bike.wheelie_finished.connect(hud.show_wheelie_result)
	bike.stoppie_finished.connect(hud.show_stoppie_result)
	bike.crashed.connect(hud.show_message.bind("QUEDA! Levante a moto"))
	bike.crashed.connect(audio.play_crash)
	bike.impacted.connect(audio.play_impact)
	touch.layout_changed.connect(_on_layout_changed)
	menu.edit_controls_requested.connect(_enter_edit_controls)
	state.money_changed.connect(hud.set_money)
	missions.carrying_changed.connect(bike.set_carrying)
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
	var kb_steer := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb_steer += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb_steer -= 1.0
	if on_foot:
		var kb_back := 0.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			kb_back -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			kb_back += 1.0
		var mv := touch.stick_vec
		if mv.length() < 0.1:
			mv = Vector2(kb_steer, kb_back)
		ped.input_move = mv
		ped.input_run = touch.run or Input.is_key_pressed(KEY_SHIFT)
		ped.view_yaw = cam.get_view_yaw()
		_zero_bike_inputs()
		if ped.state == Pedestrian.State.LIFT:
			bike.set_lift_progress(ped.lift_progress)
		return
	var kb_thr := 1.0 if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) else 0.0
	bike.input_throttle = maxf(touch.throttle, kb_thr)
	bike.input_brake_front = 1.0 if (touch.brake_front or Input.is_key_pressed(KEY_SHIFT)) else 0.0
	bike.input_brake_rear = 1.0 if (touch.brake_rear or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) else 0.0
	bike.input_steer = touch.steer if absf(touch.steer) > 0.01 else kb_steer
	bike.input_wheelie = touch.wheelie or Input.is_key_pressed(KEY_SPACE)
	bike.input_balance = touch.balance or Input.is_key_pressed(KEY_B)
	bike.input_drift = touch.drift or Input.is_key_pressed(KEY_X)
	cam.view_pitch = bike.pitch - bike.stoppie


func _zero_bike_inputs() -> void:
	bike.input_throttle = 0.0
	bike.input_brake_front = 0.0
	bike.input_brake_rear = 0.0
	bike.input_steer = 0.0
	bike.input_wheelie = false
	bike.input_balance = false
	bike.input_drift = false


func _process(_delta: float) -> void:
	if on_foot:
		hud.update_foot(ped)
	else:
		hud.update_hud(bike)
	_update_mount_label()
	hud.set_objective(missions.objective_text())
	hud.set_clock(day.clock_text())
	_update_interaction()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.keycode:
			KEY_R:
				_on_respawn_pressed()
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
	guard.rearm()


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
	_reset_to_riding()
	_start_playing()


func _to_title() -> void:
	missions.cancel()
	bike.respawn()
	_reset_to_riding()
	state.save_game()
	_enter_menu()


func _quit() -> void:
	state.save_game()
	get_tree().quit()


func _open_garage() -> void:
	if on_foot:
		menu.set_status("Suba na moto para usar a garagem.")
		return
	if mode == Mode.PAUSED and bike.global_position.distance_to(_garage_pos) > 28.0:
		menu.set_status("Vá até a GARAGEM (marcador G no minimapa).")
		return
	_return_mode = mode
	mode = Mode.GARAGE
	menu.close()
	get_tree().paused = true
	_touch_enabled(false)
	cam.showroom = true
	garage.open()


func _close_garage() -> void:
	mode = _return_mode
	if mode == Mode.MENU:
		menu.open("title")
	elif mode == Mode.PLAYING:
		_start_playing()
	else:
		cam.showroom = false
		cam.snap()
		menu.open("pause")


# ------------------------------------------------ botão de interação (acionadores)

## Descobre se o jogador está parado sobre um acionador e qual nome o botão deve ter:
## GARAGEM (garagem, só de moto), ENTREGA (hamburgueria, sem missão ativa) ou
## ENTREGAR (casa de destino da entrega em andamento).
func _compute_interaction() -> Dictionary:
	if mode != Mode.PLAYING:
		return {}
	var actor: Node3D = ped if on_foot else bike
	if on_foot:
		if not ped.can_act() or ped.speed > 1.2:
			return {}
	elif bike.fallen or bike.parked or absf(bike.speed) > 2.0:
		return {}
	var pos := actor.global_position
	for p in city_info["pois"]:
		var at: Vector3 = p["pos"]
		if Vector2(pos.x - at.x, pos.z - at.z).length() > TRIGGER_RADIUS:
			continue
		var id: String = p["id"]
		if id == "garagem" and not on_foot:
			return {"label": "GARAGEM", "kind": "garage", "id": id}
		if id.begins_with("hamburgueria_") and not missions.is_active():
			return {"label": "ENTREGA", "kind": "pickup", "id": id}
		if id.begins_with("casa_") and missions.can_deliver_at(id):
			return {"label": "ENTREGAR", "kind": "deliver", "id": id}
	return {}


func _update_interaction() -> void:
	_interaction = _compute_interaction()
	touch.interact_label = str(_interaction.get("label", ""))


func _on_interact_pressed() -> void:
	_interaction = _compute_interaction()
	match str(_interaction.get("kind", "")):
		"garage":
			_open_garage()
		"pickup":
			missions.start_delivery(str(_interaction["id"]))
		"deliver":
			var actor: Node3D = ped if on_foot else bike
			missions.deliver(actor.global_position)


# ------------------------------------------- a pé: descer, subir, cair, levantar

func _near_bike() -> bool:
	return ped.global_position.distance_to(bike.global_position) < 3.2


func _update_mount_label() -> void:
	touch.foot_mode = on_foot
	if not on_foot:
		touch.mount_label = "DESCER"
	elif ped.can_act() and _near_bike():
		touch.mount_label = "LEVANTAR" if bike.fallen else "SUBIR"
	else:
		touch.mount_label = ""


func _on_mount_pressed() -> void:
	if mode != Mode.PLAYING:
		return
	if not on_foot:
		_dismount()
	elif ped.can_act() and _near_bike():
		if bike.fallen:
			_begin_lift()
		else:
			ped.begin_mount(bike)


func _dismount() -> void:
	if bike.fallen or bike.parked:
		return
	if absf(bike.speed) > 3.0 or bike.pitch > 0.05:
		hud.show_message("Pare a moto para descer")
		return
	bike.parked = true
	bike.set_rider_visible(false)
	var side: Vector3 = bike.global_transform * Vector3(-0.95, 0.0, -0.15)
	ped.begin_dismount(bike.seat_world(), side, bike.global_rotation.y)
	_enter_foot()


func _enter_foot() -> void:
	on_foot = true
	cam.target = ped
	cam.begin_foot(ped)
	_set_player(ped)
	audio.rider_active = false


func _finish_mount() -> void:
	ped.visible = false
	ped.state = Pedestrian.State.WALK
	bike.parked = false
	bike.set_rider_visible(true)
	on_foot = false
	cam.end_foot()
	cam.target = bike
	_set_player(bike)
	audio.rider_active = true


func _reset_to_riding() -> void:
	if on_foot or bike.parked or not bike.rider_on_bike:
		_finish_mount()


func _set_player(node: Node3D) -> void:
	traffic.player = node
	missions.tracker = node
	hud.set_tracking(node)
	day.set_focus(node)


func _begin_lift() -> void:
	bike.begin_lift()
	ped.begin_lift(bike)


func _finish_lift() -> void:
	bike.finish_lift()
	hud.show_message("Moto levantada! Toque em SUBIR")


func _on_bike_crashed() -> void:
	if on_foot or mode != Mode.PLAYING:
		return
	bike.set_rider_visible(false)
	ped.global_position = bike.global_transform * Vector3(0, 0.3, -0.2)
	ped.begin_tumble(bike.crash_velocity, bike.global_rotation.y)
	_enter_foot()


func _on_respawn_pressed() -> void:
	bike.respawn()
	if on_foot:
		bike.parked = true
		bike.set_rider_visible(false)
		ped.reset_beside(bike.global_transform * Vector3(-0.95, 0.05, -0.15), bike.global_rotation.y)
		cam.begin_foot(ped)


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
	audio.play_success()
	hud.show_message("MISSÃO COMPLETA!  +" + GameState.format_money(reward))


func _on_mission_failed(_m: Dictionary, reason: String) -> void:
	audio.play_fail()
	hud.show_message("MISSÃO FALHOU: " + reason)


# ------------------------------------------------- reposicionar controles / qualidade

func _build_edit_bar(parent: Node) -> void:
	_edit_bar = VBoxContainer.new()
	_edit_bar.position = Vector2(24, 270)
	_edit_bar.add_theme_constant_override("separation", 10)
	Kit.button(_edit_bar, "RESTAURAR PADRÃO", func(): touch.reset_layout(), Color(0.4, 0.25, 0.15), Vector2(300, 60), 24)
	Kit.button(_edit_bar, "CONCLUIR", _finish_edit_controls, Color(0.15, 0.45, 0.25), Vector2(300, 60), 28)
	_edit_bar.visible = false
	parent.add_child(_edit_bar)


func _enter_edit_controls() -> void:
	menu.close()
	_touch_enabled(true)
	touch.edit_mode = true
	_edit_bar.visible = true


func _finish_edit_controls() -> void:
	touch.edit_mode = false
	_edit_bar.visible = false
	_touch_enabled(false)
	settings.control_offsets = touch.offsets.duplicate()
	settings.save_settings()
	menu.open("settings")


func _on_layout_changed() -> void:
	settings.control_offsets = touch.offsets.duplicate()
	settings.save_settings()


func _on_quality_reduced(level: int) -> void:
	hud.show_message("Qualidade reduzida (%s) para melhorar o desempenho" % GraphicsManager.NAMES[level])
	traffic.set_density(mini(traffic.density, gfx.traffic_cap()))


# --------------------------------------------------------------- configurações

func _apply_settings() -> void:
	touch.steer_sensitivity = settings.steer_sensitivity
	touch.ui_opacity = settings.control_opacity
	audio.apply_volumes(settings.volume_master, settings.volume_sfx, settings.volume_ambient)
	guard.enabled = settings.quality == 0
	gfx.apply(GraphicsManager.level_for_setting(settings.quality))
	traffic.set_density(mini(settings.traffic_density, gfx.traffic_cap()))
	day.day_minutes = settings.day_minutes
	settings.save_settings()


func _toggle_view() -> void:
	cam.toggle_view()
	_save_camera()


func _reset_camera() -> void:
	cam.reset_view()
	_save_camera()


func _save_camera() -> void:
	if not cam.free_orbit:
		settings.camera_distance = cam.distance
		settings.camera_pitch = cam.pitch_deg
		settings.camera_yaw_offset = cam.yaw_offset
	settings.camera_first_person = cam.first_person
	if day != null:
		settings.time_of_day = day.time_of_day
	settings.save_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if cam != null and settings != null:
			_save_camera()
		if state != null:
			state.save_game()
