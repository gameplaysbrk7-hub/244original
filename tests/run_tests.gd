extends SceneTree
## Testes automatizados (rodam em modo headless):
##   godot --headless --path . -s res://tests/run_tests.gd
## Saem com código 1 se qualquer verificação falhar.

const Motorcycle := preload("res://scripts/vehicle/motorcycle.gd")
const FollowCamera := preload("res://scripts/camera/follow_camera.gd")
const SettingsStore := preload("res://scripts/save/settings_store.gd")

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
	await _test_vehicle()
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
	check("configurações: salvar", s.save_settings())
	var s2 := SettingsStore.new()
	check("configurações: carregar", s2.load_settings() and is_equal_approx(s2.camera_distance, 6.5))
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
	rig.queue_free()
	dummy.queue_free()
	await _frames(2)

	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var m := packed.instantiate()
	root.add_child(m)
	await _frames(10)
	check("cena principal instancia moto, câmera e interface", m.get_node_or_null("Motorcycle") != null and m.get_node_or_null("FollowCamera") != null and m.touch != null)
	m.queue_free()
	await _frames(2)
