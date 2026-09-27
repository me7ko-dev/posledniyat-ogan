extends Node
## Автоматичен тест: `-- --autotest`. Робот тича с героя и минава основния цикъл:
## сече → носи в огъня → пътниците плащат → прибира монетите → строи всички квадрати →
## дърварите сами пазят огъня → запис. Печата RESULT: PASS/FAIL, снимки в _autotest/.
## Ползва отделен запис (autotest_save.json), истинската игра не се пипа.

const SPEED := 3.0  # времето тече 3 пъти по-бързо

var main: Node
var _fails: Array[String] = []
var _fps: Array[float] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_autotest"))
	_run.call_deferred()


func _process(_delta: float) -> void:
	_fps.append(Engine.get_frames_per_second())


func _run() -> void:
	var p = main.player
	await _wait(1.5)
	await _shot("1_start")
	Engine.time_scale = SPEED

	# 1) Сече до пълно
	var tree = main.nearest_tree(p.global_position, 100.0)
	await _go(tree.global_position + Vector3(0, 0, 1.2))
	await _until(func() -> bool: return p.stack.full() and p.stack.incoming == 0, 20.0)
	_check(p.stack.count() == p.stack.capacity, "героят сече до пълно (%d/%d)" % [p.stack.count(), p.stack.capacity])
	_check(main.tutorial >= 1, "подсказката мина към огъня")
	await _shot("2_chop")

	# 2) Хвърля дървата в огъня
	var fuel0: float = main.fire.fuel
	await _go(main.fire.global_position + Vector3(0, 0, 1.9))
	await _until(func() -> bool: return p.stack.is_empty() and main.fire.incoming == 0, 10.0)
	_check(p.stack.is_empty(), "всички дърва отидоха в огъня")
	_check(main.fire.fuel > fuel0, "огънят се разгоря (%.0f → %.0f)" % [fuel0, main.fire.fuel])

	# 3) Пътниците плащат, героят прибира монетите
	await _until(func() -> bool: return main.total_pile() >= 3, 40.0)
	_check(main.total_pile() >= 3, "пътник се стопли и плати")
	await _shot("3_travellers")
	var pile = main.fullest_pile()
	if pile:
		await _go(pile.global_position)
		await _until(func() -> bool: return main.coins > 0, 6.0)
	_check(main.coins > 0, "монетите се прибират (%d)" % main.coins)

	# 4) Строене: първият квадрат
	main.coins += 30
	var pad = main.pads.get("bench")
	_check(pad != null, "квадратът „Още пейки“ се вижда")
	if pad:
		await _go(pad.global_position)
		await _until(func() -> bool: return "bench" in main.built, 10.0)
	_check("bench" in main.built, "пейките са построени")
	_check(main.seats.size() == 5, "5 места до огъня (%d)" % main.seats.size())
	await _shot("4_built")

	# 5) Всички квадрати
	main.coins += 3000
	for id in ["backpack", "helper", "tent", "axe", "helper2", "forest", "bigfire"]:
		pad = main.pads.get(id)
		if pad == null:
			_check(false, "квадратът %s не се вижда" % id)
			continue
		await _go(pad.global_position)
		await _until(func() -> bool: return id in main.built, 15.0)
		_check(id in main.built, "построено: %s" % id)
	_check(main.helpers.size() == 2, "двама дървари (%d)" % main.helpers.size())
	_check(main.trees.size() == 13, "13 дървета след новата гора (%d)" % main.trees.size())
	_check(p.stack.capacity == 12, "раницата носи 12")

	# 6) Дърварите сами пазят огъня 90 сек
	await _go(Vector3(5.5, 0, 5.5))
	main.fire.fuel = 25.0
	var lowest := 999.0
	for i in 90:
		await _wait(1.0)
		lowest = minf(lowest, main.fire.fuel)
	_check(lowest > 0.0, "дърварите не оставят огъня да угасне (най-малко %.0f сек)" % lowest)
	_check(main.travellers.size() > 0, "пътниците идват (%d)" % main.travellers.size())
	await _go(main.fire.global_position + Vector3(0, 0, 3.0))
	await _wait(1.0)
	await _shot("5_camp")

	# 7) Огънят угасва: пътникът чака, трепери и си тръгва
	var helpers: Array = main.helpers.duplicate()
	for h in helpers:
		h.process_mode = Node.PROCESS_MODE_DISABLED
	main.fire.fuel = 0.0
	await _wait(3.0)
	_check(not main.fire.burning(), "огънят угасна")
	await _shot("6_cold")
	for h in helpers:
		h.process_mode = Node.PROCESS_MODE_INHERIT

	# 8) Запис
	var coins: int = main.coins
	main.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	_check(int(d.coins) == coins, "записът пази монетите")
	_check((d.built as Array).size() == 8, "записът пази построеното")
	_check(main.offline_gain(3600.0) > 0, "с дървари се печели и докато те няма (%d за 1 ч)" % main.offline_gain(3600.0))

	Engine.time_scale = 1.0
	var avg := 0.0
	for f in _fps:
		avg += f
	avg /= maxf(1.0, _fps.size())
	print("FPS средно: %.0f" % avg)
	if _fails.is_empty():
		print("RESULT: PASS")
	else:
		print("RESULT: FAIL")
		for f in _fails:
			print("  ✗ " + f)
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		_fails.append(what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Води героя до точката (или докато изтече времето).
func _go(to: Vector3, timeout := 15.0) -> void:
	var p = main.player
	p.bot_target = to
	var t := 0.0
	while t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
		if Vector2(p.global_position.x - to.x, p.global_position.z - to.z).length() < 0.3:
			break
	p.bot_target = null


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://_autotest/%s.png" % name))
