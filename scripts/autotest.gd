extends Node
## Автоматичен тест: `-- --autotest`. Играе по сценарий, проверява сметките, записа
## и прогреса, докато те няма. Печата RESULT: PASS/FAIL, снимки в _autotest/.
## Ползва отделен запис (autotest_save.json), истинската игра не се пипа.

const GameState := preload("res://scripts/game_state.gd")

var main: Node
var _fails: Array[String] = []
var _fps: Array[float] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_autotest"))
	_run.call_deferred()


func _process(_delta: float) -> void:
	_fps.append(Engine.get_frames_per_second())


func _run() -> void:
	var st: GameState = main.state
	var hud = main.hud
	await _wait(1.5)
	await _shot("1_start")

	# 1) Удари с брадвата
	var before := st.wood
	for i in 20:
		hud.do_tap(Vector2(360, 900))
	_check(is_equal_approx(st.wood, before + 20.0), "20 удара дават 20 дърва (дадоха %.1f)" % (st.wood - before))

	# 2) Първият оцелял
	_check(hud.try_buy(GameState.Item.RECRUIT), "купуване на оцелял")
	_check(st.survivor_count() == 2, "в лагера са 2 души")
	_check(not hud.try_buy(GameState.Item.FIRE), "огънят е твърде скъп в началото")
	await _wait(1.0)
	await _shot("2_first_recruit")

	# 3) 15 минути игра на бързи обороти: първите 3 мин удря по 2 пъти/сек, после само чака
	for sec in 900:
		st.tick(1.0)
		if sec < 180:
			for k in 2:
				st.tap()
		_bot_buy(hud, st)
		if (sec + 1) % 180 == 0:
			print("мин %2d: дърва=%d хора=%d/%d огън=%d брадви=%d ръкавици=%d  %+.1f/сек" % [
				(sec + 1) / 60, st.wood, st.survivor_count(), st.seats(), st.fire_level,
				st.axe_level, st.gloves_level, st.net_rate()])
	_check(st.survivor_count() >= 8, "след 15 мин има поне 8 души (има %d)" % st.survivor_count())
	_check(st.fire_level >= 3, "след 15 мин огънят е поне ниво 3 (ниво %d)" % st.fire_level)
	_check(st.net_rate() > 0.0, "лагерът печели дърва")
	await _wait(1.5)
	await _shot("3_camp_15min")

	# 4) Огънят гасне: голям огън, малко хора, без дърва
	var saved := st.to_dict()
	st.names.resize(2)
	st.axe_level = 0
	st.fire_level = 8
	st.wood = 0.0
	st.tick(1.0)
	_check(st.is_cold(), "огънят гасне, когато няма дърва")
	await _wait(2.5)
	await _shot("4_cold")
	st.from_dict(saved)
	_check(not st.is_cold(), "след възстановяване огънят пак гори")

	# 5) Запис и 1 час отсъствие
	main.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	d["last_seen"] = float(d["last_seen"]) - 3600.0
	var f := FileAccess.open(main.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	var st2 := GameState.new()
	_check(st2.load_from(main.save_path), "записът се чете")
	_check(st2.names == st.names and st2.fire_level == st.fire_level and st2.axe_level == st.axe_level
		and st2.gloves_level == st.gloves_level and absf(st2.wood - st.wood) < 1.0, "записът пази всичко")
	var away := st2.seconds_since_seen()
	var expected := st2.net_rate() * away
	var gained := st2.apply_offline(away)
	_check(absf(away - 3600.0) < 5.0, "отсъствие около 1 час (%.0f сек)" % away)
	_check(absf(gained - expected) <= absf(expected) * 0.01 + 1.0,
		"прогрес докато те няма: +%.0f (очаквано %.0f)" % [gained, expected])

	# таванът е 8 часа
	var st3 := GameState.new()
	st3.from_dict(st.to_dict())
	var g24 := st3.apply_offline(24.0 * 3600.0)
	_check(absf(g24 - st.net_rate() * GameState.OFFLINE_CAP) < 1.0, "таванът е 8 часа")

	hud.show_offline(away, gained)
	await _wait(1.0)
	await _shot("5_offline")

	_fps.sort()
	print("FPS: min=%d  median=%d" % [_fps[0], _fps[_fps.size() / 2]])
	for msg in _fails:
		print("  НЕ МИНА: " + msg)
	print("RESULT: %s" % ("PASS" if _fails.is_empty() else "FAIL"))
	get_tree().quit(0 if _fails.is_empty() else 1)


## Купува най-евтиното полезно нещо, докато има пари. Огънят — само когато местата са пълни.
func _bot_buy(hud, st: GameState) -> void:
	for guard in 50:
		var best := -1
		var best_cost := INF
		for item: int in GameState.Item.values():
			if item == GameState.Item.FIRE and st.has_seat():
				continue
			if item == GameState.Item.RECRUIT and not st.has_seat():
				continue
			if st.cost(item) < best_cost:
				best = item
				best_cost = st.cost(item)
		if best < 0 or not hud.try_buy(best):
			return


func _check(ok: bool, msg: String) -> void:
	print(("  ок: " if ok else "  ГРЕШКА: ") + msg)
	if not ok:
		_fails.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://_autotest/%s.png" % shot_name)
	get_viewport().get_texture().get_image().save_png(path)
