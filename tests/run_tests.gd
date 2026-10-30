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
	await _test_vehicle()
	await _test_city_and_traffic()
	await _test_missions()
	await _test_touch_wheelie()
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
		{"id": "casa_1", "name": "CASA 1", "pos": Vector3(-12, 0, 36)},
	]
	var mm := MissionManager.new()
	holder.add_child(mm)
	mm.setup(st, bike, pois)

	check("missão: inicia entrega", mm.start("entrega_1") and mm.is_active())
	check("missão: não inicia duas ao mesmo tempo", not mm.start("grau_5"))
	bike.global_position = Vector3(18, 0.3, 30)
	mm._physics_process(0.01)
	check("missão: coleta o pedido na hamburgueria e passa a carregar", mm.stage == 1)
	bike.global_position = Vector3(-12, 0.3, 36)
	mm._physics_process(0.01)
	check("missão: entrega na casa paga a recompensa", (not mm.is_active()) and st.money == 300)
	mm._physics_process(0.01)
	check("missão: sem pagamento duplicado", st.money == 300)
	mm.start("entrega_1")
	bike.global_position = Vector3(18, 0.3, 30)
	mm._physics_process(0.01)
	bike.global_position = Vector3(-12, 0.3, 36)
	mm._physics_process(0.01)
	check("missão: repetição paga 40%", st.money == 420 and int(st.completed["entrega_1"]) == 2)

	var fails := {"n": 0}
	mm.failed.connect(func(_m, _r): fails["n"] += 1)
	mm.start("entrega_4")
	for i in 200:
		mm._physics_process(1.0)
	check("missão: falha por tempo sem pagar", fails["n"] == 1 and (not mm.is_active()) and st.money == 420)

	mm.start("grau_5")
	bike.wheelie_time = 5.5
	mm._physics_process(0.01)
	check("missão: desafio de grau", (not mm.is_active()) and st.money == 770)

	mm.start("percurso_centro")
	var pts: Array = mm.active["points"].duplicate()
	for p in pts:
		bike.global_position = p + Vector3(0, 0.3, 0)
		mm._physics_process(0.01)
	check("missão: percurso com checkpoints em ordem", (not mm.is_active()) and st.money == 1370)

	mm.start("grau_10")
	mm.cancel()
	check("missão: cancelar não paga", (not mm.is_active()) and st.money == 1370)

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
	touch.queue_free()
	await _frames(2)
