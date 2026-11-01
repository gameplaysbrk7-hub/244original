extends SceneTree
## Testes automatizados (rodam em modo headless):
##   godot --headless --path . -s res://tests/run_tests.gd
## Saem com código 1 se qualquer verificação falhar.

const Motorcycle := preload("res://scripts/vehicle/motorcycle.gd")
const FollowCamera := preload("res://scripts/camera/follow_camera.gd")
const SettingsStore := preload("res://scripts/save/settings_store.gd")
const CityBuilder := preload("res://scripts/city/city_builder.gd")
const TrafficManager := preload("res://scripts/traffic/traffic_manager.gd")
const GameState := preload("res://scripts/save/game_state.gd")
const BikeCatalog := preload("res://scripts/vehicle/bike_catalog.gd")
const BikeModel := preload("res://scripts/vehicle/bike_model.gd")
const MissionManager := preload("res://scripts/missions/mission_manager.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const SoundBank := preload("res://scripts/audio/sound_bank.gd")
const AudioManager := preload("res://scripts/audio/audio_manager.gd")
const DayNight := preload("res://scripts/city/day_night.gd")
const GraphicsManager := preload("res://scripts/core/graphics_manager.gd")
const PerformanceGuard := preload("res://scripts/core/performance_guard.gd")
const Humanoid := preload("res://scripts/player/humanoid.gd")
const Pedestrian := preload("res://scripts/player/pedestrian.gd")
const PhoneUi := preload("res://scripts/ui/phone_ui.gd")

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run_all()


func check(test_name: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [OK]    ", test_name)
	else:
		failures += 1
		print("  [FALHA] ", test_name)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run_all() -> void:
	print("== Testes da Fase 1 ==")
	_test_files()
	_test_references()
	_test_settings()
	_test_models()
	_test_progression()
	_test_sounds()
	_test_settings_final()
	await _test_vehicle()
	await _test_city_and_traffic()
	await _test_missions()
	await _test_touch_wheelie()
	await _test_polish()
	_test_rider_model()
	await _test_reverse_fall_foot()
	await _test_phone_ui()
	await _test_camera_and_main()
	print("== %d verificações, %d falhas ==" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_files() -> void:
	for p in [
		"res://project.godot",
		"res://export_presets.cfg",
		"res://scenes/main/main.tscn",
		"res://resources/vehicles/starter.tres",
		"res://scripts/vehicle/motorcycle.gd",
		"res://scripts/camera/follow_camera.gd",
		"res://scripts/ui/touch_controls.gd",
		"res://scripts/city/city_builder.gd",
		"res://scripts/traffic/traffic_manager.gd",
		"res://scripts/ui/minimap.gd",
		"res://scripts/ui/menu_ui.gd",
		"res://scripts/ui/garage_ui.gd",
		"res://scripts/save/game_state.gd",
		"res://scripts/missions/mission_manager.gd",
		"res://scripts/audio/audio_manager.gd",
		"res://scripts/audio/sound_bank.gd",
		"res://scripts/city/day_night.gd",
		"res://scripts/core/graphics_manager.gd",
		"res://scripts/core/performance_guard.gd",
		"res://scripts/player/humanoid.gd",
		"res://scripts/player/pedestrian.gd",
		"res://scripts/ui/phone_ui.gd",
		"res://scripts/ui/map_screen.gd",
		"res://assets/ui/phone.png",
		"res://assets/ui/phone_button.png",
		"res://resources/vehicles/corisco.tres",
		"res://resources/vehicles/trovao.tres",
	]:
		check("arquivo existe: " + p, FileAccess.file_exists(p))
	check("cena principal carrega", load("res://scenes/main/main.tscn") is PackedScene)
	var prof: Resource = load("res://resources/vehicles/starter.tres")
	check("perfil de veículo carrega", prof != null and prof.max_speed > 0.0)


func _collect(path: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(path):
		if d.begins_with(".") or d == "build":
			continue
		_collect(path.path_join(d), out)
	for f in DirAccess.get_files_at(path):
		if f.get_extension() in ["gd", "tscn", "tres"]:
			out.append(path.path_join(f))


func _test_references() -> void:
	var files: Array = []
	_collect("res://", files)
	var re := RegEx.create_from_string("res://[A-Za-z0-9_./-]+")
	var broken: Array = []
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		for m in re.search_all(text):
			var p := m.get_string().rstrip(".,")
			if p == "res://" or p.ends_with("/"):
				continue
			if not FileAccess.file_exists(p):
				broken.append("%s -> %s" % [f, p])
	for b in broken:
		print("    referência quebrada: ", b)
	check("sem referências res:// quebradas (%d arquivos)" % files.size(), broken.is_empty())


func _test_settings() -> void:
	var s := SettingsStore.new()
	s.camera_distance = 6.5
	s.camera_first_person = true
	check("configurações: salvar", s.save_settings())
	var s2 := SettingsStore.new()
	check("configurações: carregar", s2.load_settings() and is_equal_approx(s2.camera_distance, 6.5) and s2.camera_first_person)
	var f := FileAccess.open(SettingsStore.PATH, FileAccess.WRITE)
	f.store_string("isto nao e um arquivo [[ valido ===")
	f.close()
	var s3 := SettingsStore.new()
	check("configurações: arquivo corrompido não quebra", (not s3.load_settings()) and is_equal_approx(s3.camera_distance, 4.6))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsStore.PATH))
	s.free()
	s2.free()
	s3.free()


func _test_vehicle() -> void:
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 2, 600)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -1, 0)
	root.add_child(floor_body)

	var bike := Motorcycle.new()
	bike.position = Vector3(0, 0.3, 0)
	root.add_child(bike)

	await _frames(20)
	check("moto inicializa e toca o chão", bike.is_on_floor() and bike.profile != null)

	bike.input_throttle = 1.0
	await _frames(120)
	check("acelerador aumenta a velocidade", bike.speed > 5.0)

	var v1 := bike.speed
	bike.input_throttle = 0.0
	bike.input_brake_front = 1.0
	await _frames(120)
	check("freio reduz a velocidade", bike.speed < v1 * 0.5)
	bike.input_brake_front = 0.0

	bike.input_throttle = 1.0
	await _frames(120)
	bike.input_throttle = 0.5
	bike.input_wheelie = true
	await _frames(90)
	check("grau levanta a roda dianteira", bike.pitch > 0.1 and not bike.fallen)
	check("grau mantém a moto acima do solo", bike.global_position.y > -0.1)

	bike.input_wheelie = false
	bike.input_throttle = 0.0
	await _frames(240)
	check("equilíbrio: dianteira volta ao chão", bike.pitch < 0.05)

	bike.respawn()
	check("reposicionamento zera a velocidade", bike.speed == 0.0 and not bike.fallen)

	# Equilíbrio assistido: segura o grau perto do ponto ideal
	bike.input_throttle = 1.0
	await _frames(200)
	bike.input_throttle = 0.6
	bike.input_wheelie = true
	bike.input_balance = true
	await _frames(120)
	check("botão de equilíbrio mantém o grau sem cair", bike.pitch > 0.15 and bike.pitch < 0.9 and not bike.fallen)
	bike.input_wheelie = false
	bike.input_balance = false
	bike.input_throttle = 0.0
	await _frames(240)

	# Stoppie: freio dianteiro forte em velocidade levanta a traseira
	bike.respawn()
	bike.input_throttle = 1.0
	await _frames(200)
	bike.input_throttle = 0.0
	bike.input_brake_front = 1.0
	var max_stoppie := 0.0
	for i in 90:
		await physics_frame
		max_stoppie = maxf(max_stoppie, bike.stoppie)
	check("stoppie levanta a traseira", max_stoppie > 0.05 and not bike.fallen)
	bike.input_brake_front = 0.0
	await _frames(120)
	check("stoppie volta ao chão", bike.stoppie < 0.02)

	# Borrachão: acelera com o botão de derrapar parado
	bike.respawn()
	var yaw0 := bike.rotation.y
	bike.input_throttle = 1.0
	bike.input_drift = true
	bike.input_steer = 1.0
	await _frames(60)
	check("borrachão mantém a moto quase parada e girando", bike.burnout and bike.speed < 4.0 and absf(angle_difference(yaw0, bike.rotation.y)) > 0.3)

	# Derrapagem lateral em velocidade
	bike.respawn()
	bike.input_drift = false
	bike.input_steer = 0.0
	bike.input_throttle = 1.0
	await _frames(150)
	bike.input_drift = true
	bike.input_steer = 1.0
	await _frames(40)
	check("derrapagem: corpo gira diferente da trajetória", absf(angle_difference(bike.move_yaw, bike.rotation.y)) > 0.05 and not bike.fallen)
	bike.input_drift = false
	bike.input_steer = 0.0
	bike.input_throttle = 0.0

	var corisco := BikeCatalog.load_profile("corisco")
	bike.set_profile(corisco, BikeModel.default_custom(corisco))
	await _frames(30)
	check("troca de moto: entre-eixos e colisão atualizados", is_equal_approx(bike.front_axle_z, -1.28) and bike.is_on_floor())
	var cust := BikeModel.default_custom(corisco)
	cust["body_color"] = Color(0.2, 0.9, 0.3)
	cust["suspension"] = 2
	bike.apply_customization(cust)
	check("personalização aplicada na moto em jogo", (bike.parts["mats"]["body"] as StandardMaterial3D).albedo_color.is_equal_approx(Color(0.2, 0.9, 0.3)))

	bike.queue_free()
	floor_body.queue_free()
	await _frames(2)


func _test_camera_and_main() -> void:
	var dummy := Node3D.new()
	root.add_child(dummy)
	var rig := FollowCamera.new()
	root.add_child(rig)
	rig.target = dummy
	await _frames(30)
	var dist := rig.camera.global_position.distance_to(dummy.global_position)
	check("câmera acompanha o alvo a distância razoável", dist > 1.0 and dist < 12.0)
	rig.orbit(Vector2(100, 0))
	check("câmera orbita por gesto", absf(rig.yaw_offset) > 0.1)
	rig.reset_view()
	check("câmera volta à posição padrão", is_zero_approx(rig.yaw_offset))
	rig.toggle_view()
	await _frames(5)
	check("câmera em primeira pessoa fica junto da moto", rig.first_person and rig.camera.global_position.distance_to(dummy.global_position) < 2.5)
	rig.toggle_view()
	rig.queue_free()
	dummy.queue_free()
	await _frames(2)

	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var m := packed.instantiate()
	root.add_child(m)
	await _frames(10)
	check("cena principal instancia moto, câmera, interface, trânsito, missões e menus", m.get_node_or_null("Motorcycle") != null and m.get_node_or_null("FollowCamera") != null and m.touch != null and m.get_node_or_null("Traffic") != null and m.get_node_or_null("Missions") != null and m.menu != null and m.state != null)
	check("jogo começa na tela inicial", m.mode == 0 and m.menu.visible)
	m.menu.open("missions")
	m.menu.open("settings")
	m.garage.open()
	await _frames(3)
	check("garagem abre com a moto em vitrine", m.garage.visible and m.cam.showroom)
	m.garage.close()
	m._start_playing()
	await _frames(5)
	check("jogar libera a simulação", m.mode == 1 and not m.get_tree().paused)
	m.bike.input_brake_rear = 0.0
	m._open_phone()
	check("celular: o botão abre o celular e pausa o jogo", m.mode == 4 and m.phone.visible and m.get_tree().paused)
	for i in 3:
		m.phone._process(0.2)
	var evp := InputEventMouseButton.new()
	evp.button_index = MOUSE_BUTTON_LEFT
	evp.pressed = true
	evp.position = m.phone.app_center("configuracoes")
	m.phone._gui_input(evp)
	for i in 3:
		m.phone._process(0.2)
	check("celular: Configurações abre direto, sem passar pela pausa", m.menu.visible and m.menu._current == "settings" and m.menu.phone_origin and m.mode == 4)
	m.menu._go_back()
	check("celular: voltar das configurações retoma o jogo", m.mode == 1 and (not m.menu.visible) and not m.get_tree().paused)
	m.menu.open("pause")
	var pause_texts: Array = []
	for bc in m.menu._box.get_children():
		if bc is Button:
			pause_texts.append((bc as Button).text)
	check("pausa: configurações só existem pelo celular", not pause_texts.has("CONFIGURAÇÕES"))
	m.menu.close()
	m._start_playing()
	m._launch_app("entregas")
	check("celular: app Entregas abre", m.menu._current == "deliveries" and m.menu.visible)
	m.menu._go_back()
	m._launch_app("ligacoes")
	check("celular: app Ligações abre", m.menu._current == "calls" and m.menu.visible)
	m.menu._go_back()
	m._launch_app("corridas")
	check("celular: app Corridas abre a lista de missões", m.menu._current == "missions" and m.menu.visible)
	m.menu._go_back()
	m._launch_app("mapa")
	check("celular: app Mapa abre o mapa grande", m.map_screen.visible)
	m.map_screen._close()
	check("celular: fechar o mapa retoma o jogo", m.mode == 1 and not m.map_screen.visible)
	var photo_path: String = m._save_photo(Image.create(32, 32, false, Image.FORMAT_RGB8))
	check("celular: app Câmera salva a foto", photo_path != "" and FileAccess.file_exists(photo_path))
	if photo_path != "":
		DirAccess.remove_absolute(photo_path)
	var garage_pos := Vector3.ZERO
	var burger_pos := Vector3.ZERO
	for pp in m.city_info["pois"]:
		if pp["id"] == "garagem":
			garage_pos = pp["pos"]
		if pp["id"] == "hamburgueria_1":
			burger_pos = pp["pos"]
	m.bike.global_position = garage_pos + Vector3(0, 0.3, 0)
	await _frames(5)
	check("interação: parado na garagem o botão vira GARAGEM", m.touch.interact_label == "GARAGEM")
	m._on_interact_pressed()
	check("interação: o botão abre a garagem sem passar pela pausa", m.mode == 3 and m.garage.visible)
	m.garage._on_back()
	await _frames(3)
	check("interação: sair da garagem volta direto ao jogo", m.mode == 1 and not m.get_tree().paused)
	m.bike.global_position = burger_pos + Vector3(0, 0.3, 0)
	await _frames(5)
	check("interação: parado na hamburgueria o botão vira ENTREGA", m.touch.interact_label == "ENTREGA")
	var money_before: int = m.state.money
	m._on_interact_pressed()
	check("interação: ENTREGA sorteia a missão de entrega", m.missions.is_active() and m.missions.active["type"] == "delivery")
	m.menu.open_from_phone("deliveries")
	check("celular: app Entregas mostra a entrega em andamento", m.menu._box.get_child_count() > 6)
	m.menu.close()
	await _frames(3)
	check("interação: com missão ativa o botão da hamburgueria some", m.touch.interact_label == "")
	var dest_id: String = m.missions.active["to"]
	var dest_at := Vector3.ZERO
	for pp in m.city_info["pois"]:
		if pp["id"] == dest_id:
			dest_at = pp["pos"]
	m.bike.global_position = dest_at + Vector3(0, 0.3, 0)
	await _frames(8)
	check("interação: chegar na casa não entrega sozinho; o botão vira ENTREGAR", m.missions.is_active() and m.touch.interact_label == "ENTREGAR")
	m._on_interact_pressed()
	check("interação: ENTREGAR conclui a entrega e paga", (not m.missions.is_active()) and m.state.money > money_before)
	m.bike.global_position = m.city_info["spawn"] + Vector3(0, 0.3, 0)
	await _frames(5)
	m._dismount()
	check("a pé: descer da moto parada", m.on_foot and m.bike.parked and m.ped.visible)
	await _frames(45)
	check("a pé: personagem fica livre e perto da moto pode subir", m.ped.state == Pedestrian.State.WALK and m.touch.foot_mode and m.touch.mount_label == "SUBIR")
	m.state.money = 500
	m.ped.global_position = m.bike.global_position + Vector3(0, 0.2, -60)
	await _frames(3)
	m._on_tow_requested()
	check("guincho: a pé, traz a moto até o personagem e cobra a taxa", m.state.money == 400 and m.bike.global_position.distance_to(m.ped.global_position) < 4.0 and m.bike.parked and not m.bike.fallen)
	m._on_mount_pressed()
	await _frames(50)
	check("a pé: subir na moto devolve o controle", (not m.on_foot) and (not m.bike.parked) and m.bike.rider_on_bike and not m.ped.visible)
	m.bike._crash()
	check("queda: ao bater o piloto cai da moto", m.on_foot and m.bike.fallen and m.ped.state == Pedestrian.State.TUMBLE)
	await _frames(170)
	check("queda: personagem levanta e pode levantar a moto", m.ped.state == Pedestrian.State.WALK and m.touch.mount_label == "LEVANTAR")
	m._on_mount_pressed()
	await _frames(130)
	check("queda: moto levantada fica estacionada em pé", (not m.bike.fallen) and m.bike.parked and m.touch.mount_label == "SUBIR")
	m._on_mount_pressed()
	await _frames(50)
	check("queda: depois de levantar dá para subir e pilotar de novo", (not m.on_foot) and not m.bike.parked)
	check("áudio, dia/noite, gráficos e proteção de desempenho presentes", m.audio != null and m.day != null and m.gfx != null and m.guard != null)
	for t in ["sound", "graphics", "controls"]:
		m.menu._set_stab(t)
	m._enter_edit_controls()
	check("reposicionar controles liga o modo de edição", m.touch.edit_mode and m._edit_bar.visible)
	m._finish_edit_controls()
	check("concluir desliga o modo de edição", (not m.touch.edit_mode) and (not m._edit_bar.visible))
	m.queue_free()
	await _frames(2)


func _test_city_and_traffic() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var info: Dictionary = CityBuilder.build(holder)
	check("cidade: 3 ruas em cada direção e pontos de interesse", info["roads"].size() == 3 and info["pois"].size() >= 15)
	var ids: Array = []
	for p in info["pois"]:
		ids.append(p["id"])
	check("cidade: garagem, oficina, posto e treino existem", ids.has("garagem") and ids.has("oficina") and ids.has("posto") and ids.has("treino"))
	var deliveries_ok := true
	for k in ["hamburgueria_1", "hamburgueria_2", "hamburgueria_3"]:
		deliveries_ok = deliveries_ok and ids.has(k)
	for k in 8:
		deliveries_ok = deliveries_ok and ids.has("casa_%d" % (k + 1))
	check("cidade: 3 hamburguerias e 8 casas de entrega", deliveries_ok)
	check("cidade: chão com colisão", holder.get_node_or_null("Ground") != null)
	var spawn: Vector3 = info["spawn"]
	check("cidade: ponto de partida dentro do mapa", absf(spawn.x) < 100.0 and absf(spawn.z) < 100.0)

	var player := Node3D.new()
	player.position = spawn
	holder.add_child(player)
	var mgr := TrafficManager.new()
	holder.add_child(mgr)
	mgr.setup(info["roads"], player, 8)
	check("trânsito: carros criados", mgr.cars.size() == 8)
	var start: Array = []
	for c in mgr.cars:
		start.append(c.position)
	await _frames(120)
	var moved := 0
	for i in mgr.cars.size():
		if mgr.cars[i].position.distance_to(start[i]) > 1.0:
			moved += 1
	check("trânsito: carros se movem", moved >= 3)
	await _frames(900)
	var inside := true
	for c in mgr.cars:
		if absf(c.position.x) > 105.0 or absf(c.position.z) > 105.0 or absf(c.position.y) > 0.5:
			inside = false
	check("trânsito: carros permanecem no mapa", inside)
	mgr.time = 2.0
	var ew_early := mgr.light_state(0)
	var ns_early := mgr.light_state(1)
	mgr.time = 12.0
	check("semáforos alternam entre os eixos", ew_early == 0 and ns_early == 2 and mgr.light_state(0) == 2 and mgr.light_state(1) == 0)
	holder.queue_free()
	await _frames(2)


func _count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


func _remove_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p: String = path + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _test_models() -> void:
	for id in BikeCatalog.ids():
		var prof := BikeCatalog.load_profile(id)
		check("moto %s: perfil carrega" % id, prof != null and prof.max_speed > 0.0)
		var custom := BikeModel.default_custom(prof)
		var parts := BikeModel.build(prof, custom)
		var n := _count_nodes(parts["root"])
		check("moto %s: modelo detalhado (%d peças)" % [id, n], n > 80)
		custom["body_color"] = Color(0.1, 0.8, 0.2)
		custom["sticker"] = "listras"
		BikeModel.apply_custom(parts, custom)
		var mat: StandardMaterial3D = parts["mats"]["body"]
		check("moto %s: pintura altera o material real" % id, mat.albedo_color.is_equal_approx(Color(0.1, 0.8, 0.2)) and parts["sticker_stripes"].visible and not parts["sticker_number"].visible)
		parts["root"].free()


func _test_progression() -> void:
	var path := "user://test_save.json"
	_remove_save(path)
	var st := GameState.new()
	st.save_path = path
	var loaded := st.load_game()
	check("progressão: sem arquivo começa com padrão válido", (not loaded) and st.money == 500 and st.selected_bike == "starter" and st.unlocked_bikes == ["starter"])

	st.add_money(1000)
	st.set_custom_value("starter", "body_color", Color(0.1, 0.2, 0.3))
	st.set_custom_value("starter", "suspension", 2)
	check("progressão: salvar", st.save_game())
	var st2 := GameState.new()
	st2.save_path = path
	var base := BikeModel.default_custom(BikeCatalog.load_profile("starter"))
	var c2 := st2.get_custom("starter", base)
	check("progressão: carregar dinheiro e personalização", st2.load_game() and st2.money == 1500 and absf(st2.get_custom("starter", base)["body_color"].r - 0.1) < 0.01 and int(st2.get_custom("starter", base)["suspension"]) == 2)

	st.add_money(500)
	st.save_game()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ arquivo corrompido")
	f.close()
	var st3 := GameState.new()
	st3.save_path = path
	check("progressão: arquivo corrompido volta ao backup", st3.load_game() and st3.money == 1500)
	var fb := FileAccess.open(path + ".bak", FileAccess.WRITE)
	fb.store_string("lixo")
	fb.close()
	var st4 := GameState.new()
	st4.save_path = path
	check("progressão: sem backup válido usa o padrão sem travar", (not st4.load_game()) and st4.money == 500)

	var shop := GameState.new()
	shop.save_path = "user://test_save_shop.json"
	shop.money = 1000
	check("loja: moto cara sem saldo é recusada", (not shop.buy_bike("corisco", 5500)) and shop.money == 1000 and not shop.unlocked_bikes.has("corisco"))
	shop.money = 6000
	check("loja: compra desconta e desbloqueia", shop.buy_bike("corisco", 5500) and shop.money == 500 and shop.unlocked_bikes.has("corisco"))
	check("loja: não compra duas vezes", not shop.buy_bike("corisco", 5500) and shop.money == 500)
	shop.money = 700
	check("loja: item personalizado", shop.buy_item("bau", 600) and shop.owned_items.has("bau") and shop.money == 100)

	var rw := GameState.new()
	rw.save_path = "user://test_save_rw.json"
	rw.money = 0
	var paid := rw.claim_reward("m1", "m1#1", 300)
	var again := rw.claim_reward("m1", "m1#1", 300)
	var repeat := rw.claim_reward("m1", "m1#2", 300)
	check("recompensa: paga uma vez por execução e 40% nas repetições", paid == 300 and again == 0 and repeat == 120 and rw.money == 420)

	for x in [st, st2, st3, st4, shop, rw]:
		x.free()
	for pth in [path, "user://test_save_shop.json", "user://test_save_rw.json"]:
		_remove_save(pth)


func _test_missions() -> void:
	var save_path := "user://test_save_missions.json"
	_remove_save(save_path)
	var holder := Node3D.new()
	root.add_child(holder)
	var bike := Motorcycle.new()
	bike.position = Vector3(0, 0.3, 0)
	holder.add_child(bike)
	var st := GameState.new()
	st.save_path = save_path
	holder.add_child(st)
	st.money = 0
	var pois := [
		{"id": "hamburgueria_1", "name": "HAMBURGUERIA 1", "pos": Vector3(18, 0, 30)},
		{"id": "casa_1", "name": "CASA 1", "pos": Vector3(-60, 0, 40)},
		{"id": "casa_2", "name": "CASA 2", "pos": Vector3(70, 0, -40)},
		{"id": "casa_3", "name": "CASA 3", "pos": Vector3(0, 0, -90)},
	]
	var mm := MissionManager.new()
	holder.add_child(mm)
	mm.setup(st, bike, pois)

	mm.rng.seed = 7
	check("entrega: hamburgueria sorteia uma entrega", mm.start_delivery("hamburgueria_1") and mm.is_active() and mm.active["type"] == "delivery")
	var dest: String = mm.active["to"]
	var dest_pos: Vector3 = mm.objective_pos()
	var first_reward := int(mm.active["reward"])
	check("entrega: destino é uma casa a mais de 50 m", dest.begins_with("casa_") and Vector2(dest_pos.x - 18.0, dest_pos.z - 30.0).length() >= 50.0 and first_reward >= 100)
	check("entrega: não inicia duas missões ao mesmo tempo", (not mm.start("grau_5")) and (not mm.start_delivery("hamburgueria_1")))
	check("entrega: o pedido já fica na moto", mm.stage == 1)
	bike.global_position = dest_pos + Vector3(0, 0.3, 0)
	mm._physics_process(0.01)
	check("entrega: chegar ao destino NÃO conclui sozinho", mm.is_active() and st.money == 0)
	check("entrega: não entrega longe do destino", not mm.deliver(Vector3(0, 0, 0)))
	check("entrega: botão ENTREGAR no destino conclui e paga", mm.can_deliver_at(dest) and mm.deliver(dest_pos) and (not mm.is_active()) and st.money == first_reward)
	check("entrega: sem pagamento duplicado", (not mm.deliver(dest_pos)) and st.money == first_reward)
	var expected := first_reward
	mm.start_delivery("hamburgueria_1", dest)
	mm.deliver(dest_pos)
	expected += int(round(first_reward * 0.4))
	check("entrega: repetir o mesmo trajeto paga 40%", st.money == expected)

	var fails := {"n": 0}
	mm.failed.connect(func(_m, _r): fails["n"] += 1)
	mm.start_delivery("hamburgueria_1", dest)
	for i in 400:
		mm._physics_process(1.0)
	check("entrega: falha por tempo sem pagar", fails["n"] == 1 and (not mm.is_active()) and st.money == expected)

	mm.start("grau_5")
	bike.wheelie_time = 5.5
	mm._physics_process(0.01)
	expected += 350
	check("missão: desafio de grau", (not mm.is_active()) and st.money == expected)

	mm.start("percurso_centro")
	var pts: Array = mm.active["points"].duplicate()
	for p in pts:
		bike.global_position = p + Vector3(0, 0.3, 0)
		mm._physics_process(0.01)
	expected += 600
	check("missão: percurso com checkpoints em ordem", (not mm.is_active()) and st.money == expected)

	mm.start("grau_10")
	mm.cancel()
	check("missão: cancelar não paga", (not mm.is_active()) and st.money == expected)

	holder.queue_free()
	await _frames(2)
	_remove_save(save_path)


func _test_touch_wheelie() -> void:
	var touch := TouchControls.new()
	root.add_child(touch)
	await _frames(2)
	check("controles: não existe mais botão GRAU", not touch._layout().has("wheelie"))
	touch._on_press(0, Vector2(150, 500))
	touch._on_drag(0, Vector2(150, 500), Vector2.ZERO)
	check("controles: analógico parado não liga o grau", not touch.wheelie)
	touch._on_drag(0, Vector2(150, 700), Vector2(0, 200))
	check("controles: puxar o analógico para trás liga o grau", touch.wheelie)
	touch._on_drag(0, Vector2(150, 500), Vector2(0, -200))
	check("controles: empurrar de volta desliga o grau", not touch.wheelie)
	touch._on_drag(0, Vector2(150, 700), Vector2(0, 200))
	touch._on_release(0)
	check("controles: soltar o analógico desliga o grau e zera a direção", (not touch.wheelie) and is_zero_approx(touch.steer))
	var base: Vector2 = touch._layout()["throttle"]["c"]
	touch.offsets["throttle"] = Vector2(-0.1, 0.0)
	var shifted: Vector2 = touch._layout()["throttle"]["c"]
	check("controles: deslocamento salvo move o botão", is_equal_approx(base.x - shifted.x, 0.1 * touch.get_viewport_rect().size.x))
	touch.edit_mode = true
	touch._on_press(1, shifted)
	touch._on_drag(1, shifted + Vector2(-50, 0), Vector2(-50, 0))
	touch._on_release(1)
	check("controles: arrastar no modo de edição reposiciona o botão", (touch.offsets["throttle"] as Vector2).x < -0.1)
	check("controles: modo de edição não dispara a aceleração", touch.throttle == 0.0)
	touch.reset_layout()
	check("controles: restaurar padrão limpa as posições", touch.offsets.is_empty())
	touch.edit_mode = false
	touch.foot_mode = true
	touch.mount_label = "SUBIR"
	var lay: Dictionary = touch._layout()
	check("controles a pé: CORRER e SUBIR, sem os botões da moto", lay.has("run") and lay.has("mount") and not lay.has("throttle") and not lay.has("brake_rear"))
	touch.mount_label = ""
	check("controles a pé: sem moto por perto não há botão SUBIR", not touch._layout().has("mount"))
	touch._on_press(0, Vector2(150, 500))
	touch._on_drag(0, Vector2(150, 700), Vector2(0, 200))
	check("controles a pé: analógico vira movimento e não liga o grau", touch.stick_vec.y > 0.5 and not touch.wheelie)
	touch._on_release(0)
	touch.interact_label = "GARAGEM"
	check("controles a pé: botão de interação aparece com nome variável", touch._layout().has("interact") and touch._layout()["interact"]["t"] == "GARAGEM")
	touch.foot_mode = false
	check("controles: EQUIL foi substituído pelo botão de interação", not touch._layout().has("balance") and touch._layout()["interact"]["t"] == "GARAGEM")
	touch.interact_label = "ENTREGAR"
	check("controles: nome do botão muda (ENTREGAR)", touch._layout()["interact"]["t"] == "ENTREGAR")
	touch.interact_label = ""
	check("controles: sem acionador o botão de interação some", not touch._layout().has("interact"))
	check("controles na moto: botão DESCER existe", touch._layout()["mount"]["t"] == "DESCER")
	check("celular: botão só com imagem (sem texto) na moto e a pé", touch._layout()["phone"]["t"] == "" and touch._layout()["phone"]["icon"])
	touch.foot_mode = true
	check("celular: botão também existe a pé", touch._layout().has("phone"))
	touch.foot_mode = false
	var phone_flag := {"p": false}
	touch.phone_pressed.connect(func(): phone_flag["p"] = true)
	touch._on_press(3, touch._layout()["phone"]["c"])
	touch._on_release(3)
	check("celular: tocar no botão emite a abertura", phone_flag["p"])
	touch.queue_free()
	await _frames(2)


func _test_sounds() -> void:
	var eng := SoundBank.engine()
	check("sons: motor em laço com dados", eng.loop_mode == AudioStreamWAV.LOOP_FORWARD and eng.data.size() > 40000)
	var ok := true
	for snd in [SoundBank.skid(), SoundBank.wind(), SoundBank.ambient(), SoundBank.impact(), SoundBank.crash(), SoundBank.click(), SoundBank.success(), SoundBank.fail()]:
		ok = ok and snd.data.size() > 100
	check("sons: derrapagem, vento, ambiente, impacto, queda, clique e jingles gerados", ok)


func _test_settings_final() -> void:
	var s := SettingsStore.new()
	s.volume_master = 0.4
	s.quality = 3
	s.day_minutes = 12.0
	s.time_of_day = 21.5
	s.traffic_density = 14
	s.control_offsets = {"throttle": Vector2(-0.05, 0.02)}
	check("configurações finais: salvar", s.save_settings())
	var s2 := SettingsStore.new()
	var loaded := s2.load_settings()
	check("configurações finais: volume, qualidade, dia/noite, trânsito e posições dos botões", loaded and is_equal_approx(s2.volume_master, 0.4) and s2.quality == 3 and is_equal_approx(s2.day_minutes, 12.0) and is_equal_approx(s2.time_of_day, 21.5) and s2.traffic_density == 14 and s2.control_offsets.has("throttle") and (s2.control_offsets["throttle"] as Vector2).is_equal_approx(Vector2(-0.05, 0.02)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SettingsStore.PATH))
	s.free()
	s2.free()


func _test_polish() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var bike := Motorcycle.new()
	holder.add_child(bike)
	var am := AudioManager.new()
	holder.add_child(am)
	am.bike = bike
	await _frames(2)
	bike.speed = 0.0
	bike.input_throttle = 0.0
	for i in 20:
		am._process(0.1)
	var idle: float = am._engine.pitch_scale
	bike.burnout = true
	for i in 20:
		am._process(0.1)
	var rev: float = am._engine.pitch_scale
	check("áudio: rotação do motor sobe no borrachão", rev > idle + 0.5)
	bike.burnout = false
	bike.skid_level = 1.0
	am._process(0.1)
	check("áudio: derrapagem fica audível", am._skid.volume_db > -10.0)
	am.apply_volumes(0.5, 0.5, 0.5)
	var idx := AudioServer.get_bus_index("SFX")
	check("áudio: volume por barramento", idx != -1 and is_equal_approx(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5)))
	am.apply_volumes(1.0, 1.0, 1.0)

	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var sun := DirectionalLight3D.new()
	holder.add_child(sun)
	var lit := StandardMaterial3D.new()
	lit.emission_enabled = true
	var dn := DayNight.new()
	holder.add_child(dn)
	dn.day_minutes = 0.0
	dn.setup(env, sky, sun, [lit], [Vector3(5, 5, 5)], bike)
	dn.set_time(12.0)
	check("dia: ao meio-dia é dia claro, sem janelas acesas", dn.night < 0.05 and sun.light_energy > 0.9 and lit.emission_energy_multiplier < 0.05 and not bike._headlight.visible)
	dn.set_time(0.0)
	dn._update_lamp_lights()
	check("noite: escurece, acende janelas, farol e luz de poste", dn.night > 0.95 and sun.light_energy < 0.3 and lit.emission_energy_multiplier > 1.0 and bike._headlight.visible and dn._omnis[0].visible)
	dn.set_time(9.5)
	check("relógio do jogo", dn.clock_text() == "09:30")

	var cam := Camera3D.new()
	holder.add_child(cam)
	var tmgr := TrafficManager.new()
	holder.add_child(tmgr)
	var gfx := GraphicsManager.new()
	holder.add_child(gfx)
	gfx.setup(sun, cam, tmgr, dn, root)
	gfx.apply(0)
	check("gráficos: qualidade baixa desliga sombras e reduz alcance", (not sun.shadow_enabled) and cam.far < 150.0 and tmgr.active_range < 80.0 and gfx.traffic_cap() == 8)
	gfx.apply(2)
	check("gráficos: qualidade alta liga sombras", sun.shadow_enabled and cam.far > 250.0 and gfx.traffic_cap() == 30)
	check("gráficos: configuração manual escolhe o nível", GraphicsManager.level_for_setting(1) == 0 and GraphicsManager.level_for_setting(3) == 2)
	var guard := PerformanceGuard.new()
	holder.add_child(guard)
	guard.graphics = gfx
	guard.evaluate(10.0)
	check("desempenho: uma medição ruim ainda não reduz", gfx.level == 2)
	guard.evaluate(12.0)
	check("desempenho: duas medições ruins reduzem um nível", gfx.level == 1)
	guard.evaluate(60.0)
	guard.evaluate(10.0)
	check("desempenho: medição boa zera a contagem", gfx.level == 1)
	guard.evaluate(10.0)
	guard.evaluate(10.0)
	guard.evaluate(10.0)
	guard.evaluate(10.0)
	check("desempenho: nunca passa do nível mais baixo", gfx.level == 0)
	holder.queue_free()
	await _frames(2)


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _test_rider_model() -> void:
	var hn := Node3D.new()
	root.add_child(hn)
	var h := Humanoid.new()
	h.build(hn)
	h.pose(Pedestrian._stand())
	check("humanoide: membros, cabeça e mãos criados", h.root.get_child_count() >= 15)
	var knee := Humanoid.ik(Vector3(0, 0.93, 0), Vector3(0, 0.08, 0), 0.45, 0.45, Vector3(0, 0, -1))
	check("humanoide: cinemática inversa respeita o osso e dobra o joelho para frente", absf(knee.distance_to(Vector3(0, 0.93, 0)) - 0.45) < 0.01 and knee.z < 0.0)
	var a := Pedestrian.walk_pose(0.0, 0.0, 1.0)
	var b := Pedestrian.walk_pose(PI / 2.0, 0.0, 1.0)
	check("animação de caminhar move os pés", not (a["foot_l"] as Vector3).is_equal_approx(b["foot_l"]))
	var run_pose := Pedestrian.walk_pose(PI / 2.0, 1.0, 1.0)
	check("animação de correr tem passada maior que a de andar", absf((run_pose["foot_l"] as Vector3).z) > absf((b["foot_l"] as Vector3).z))
	hn.free()
	for id in BikeCatalog.ids():
		var prof := BikeCatalog.load_profile(id)
		var parts := BikeModel.build(prof, BikeModel.default_custom(prof))
		var holder := Node3D.new()
		root.add_child(holder)
		holder.add_child(parts["root"])
		var stray := 0
		for mi in _meshes(parts["root"]):
			if mi.material_override == parts["mats"]["body"]:
				var gp: Vector3 = mi.global_position
				if absf(gp.x) < 0.2 and gp.y > 1.2 and gp.y < 1.55 and gp.z > -0.65 and gp.z < -0.15:
					stray += 1
		check("moto %s: sem peça colorida solta no peito do piloto" % id, stray == 0)
		holder.free()


func _test_reverse_fall_foot() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 2, 600)
	cs.shape = bs
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -1, 0)
	holder.add_child(floor_body)
	var bike := Motorcycle.new()
	bike.position = Vector3(0, 0.3, 0)
	holder.add_child(bike)
	await _frames(20)

	var z0 := bike.global_position.z
	bike.input_brake_rear = 1.0
	await _frames(90)
	check("ré: freio traseiro com a moto parada anda para trás", bike.reversing and bike.speed < -0.8 and bike.global_position.z > z0 + 0.5)
	bike.input_brake_rear = 0.0
	await _frames(40)
	check("ré: soltar o freio para a moto", absf(bike.speed) < 0.1 and not bike.reversing)
	bike.input_throttle = 1.0
	await _frames(100)
	bike.input_throttle = 0.0
	bike.input_brake_rear = 1.0
	var never_reverse := true
	for i in 200:
		await physics_frame
		if bike.speed < -0.05:
			never_reverse = false
	check("ré: frear em movimento até parar não engata a ré sozinha", never_reverse)
	bike.input_brake_rear = 0.0

	bike.respawn()
	bike._crash()
	await _frames(150)
	check("queda: a moto continua no chão até ser levantada", bike.fallen and absf(bike.lean) > 1.0)

	var ped := Pedestrian.new()
	holder.add_child(ped)
	await _frames(2)
	ped.begin_lift(bike)
	bike.begin_lift()
	var lifted := {"done": false}
	ped.lift_finished.connect(func(): lifted["done"] = true)
	for i in 160:
		await physics_frame
		bike.set_lift_progress(ped.lift_progress)
		if lifted["done"]:
			break
	check("queda: personagem levanta a moto do chão", lifted["done"])
	bike.finish_lift()
	check("queda: depois de levantada a moto fica em pé e estacionada", (not bike.fallen) and bike.parked and absf(bike.lean) < 0.05)

	ped.reset_beside(Vector3(20, 0.1, 20), 0.0)
	await _frames(10)
	var p0 := ped.global_position
	ped.input_move = Vector2(0, -1)
	ped.view_yaw = 0.0
	await _frames(60)
	var walked := p0.distance_to(ped.global_position)
	check("a pé: andar para frente com o analógico", ped.global_position.z < p0.z - 1.5)
	ped.reset_beside(Vector3(20, 0.1, 20), 0.0)
	await _frames(10)
	p0 = ped.global_position
	ped.input_run = true
	await _frames(60)
	check("a pé: correr é mais rápido que andar", p0.distance_to(ped.global_position) > walked * 1.5)
	ped.input_move = Vector2.ZERO
	ped.input_run = false

	ped.begin_dismount(Vector3(0, 0, 0), Vector3(1, 0, 0), 0.0)
	check("a pé: animação de descer começa", ped.state == Pedestrian.State.DISMOUNT)
	await _frames(40)
	check("a pé: animação de descer termina e libera o personagem", ped.state == Pedestrian.State.WALK)
	var mounted := {"ok": false}
	ped.mount_finished.connect(func(): mounted["ok"] = true)
	ped.begin_mount(bike)
	await _frames(50)
	check("a pé: animação de subir termina", mounted["ok"])

	ped.reset_beside(Vector3(40, 0.1, 40), 0.0)
	await _frames(10)
	p0 = ped.global_position
	ped.begin_tumble(Vector3(0, 0, -8), 0.0)
	await _frames(20)
	check("queda: personagem é arremessado e desliza", ped.state == Pedestrian.State.TUMBLE and ped.global_position.z < p0.z - 1.0)
	await _frames(160)
	check("queda: personagem se levanta sozinho", ped.state == Pedestrian.State.WALK)
	holder.queue_free()
	await _frames(2)


func _test_phone_ui() -> void:
	var ph := PhoneUi.new()
	root.add_child(ph)
	await _frames(2)
	var events := {"apps": [], "closed": 0}
	ph.app_pressed.connect(func(a): events["apps"].append(a))
	ph.closed.connect(func(): events["closed"] += 1)
	check("celular: começa escondido", not ph.visible)
	ph.open()
	check("celular: começa abaixo da borda da tela", ph.phone_rect().position.y >= ph.size.y)
	for i in 3:
		ph._process(0.2)
	var r := ph.phone_rect()
	check("celular: depois de subir fica todo visível do lado direito", ph.shown >= 1.0 and r.position.x > ph.size.x * 0.5 and r.position.y >= 0.0 and r.end.y <= ph.size.y and r.end.x <= ph.size.x)
	var xc := ph.close_center()
	check("celular: o X fica no canto superior direito", xc.x > r.position.x + r.size.x * 0.8 and xc.y < r.position.y + r.size.y * 0.2)
	for app in PhoneUi.APPS:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = ph.app_center(app)
		ph._gui_input(ev)
	var apps: Array = events["apps"]
	check("celular: cada um dos 6 ícones dispara a sua função", apps.size() == 6 and apps.has("mapa") and apps.has("entregas") and apps.has("corridas") and apps.has("configuracoes") and apps.has("ligacoes") and apps.has("camera"))
	var xev := InputEventMouseButton.new()
	xev.button_index = MOUSE_BUTTON_LEFT
	xev.pressed = true
	xev.position = xc
	ph._gui_input(xev)
	for i in 3:
		ph._process(0.2)
	check("celular: tocar no X fecha e o celular desce", events["closed"] == 1 and not ph.visible)
	check("celular: imagens do celular e do botão carregam", load("res://assets/ui/phone.png") is Texture2D and load("res://assets/ui/phone_button.png") is Texture2D)
	ph.queue_free()
	await _frames(2)
