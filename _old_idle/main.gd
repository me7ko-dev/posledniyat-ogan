extends Node
## „Последният огън“ — idle игра за оцеляване.
## Етап 1: огън, дърва, оцелели, 3 подобрения, прогрес докато те няма, запис.
## Всичко се строи от код, за да е лесно за промяна.

const GameState := preload("res://scripts/game_state.gd")
const Hud := preload("res://scripts/hud.gd")
const NightSky := preload("res://scripts/sky.gd")

const SAVE_PATH := "user://save.json"
const TEST_SAVE_PATH := "user://autotest_save.json"
const AUTOSAVE_EVERY := 10.0
const MIN_AWAY := 60.0  # под минута отсъствие не показваме „Докато те нямаше“

var state: GameState
var hud: Hud
var save_path := SAVE_PATH
var _autosave_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var autotest := "--autotest" in args
	if autotest:
		save_path = TEST_SAVE_PATH
	if autotest or "--reset" in args:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	add_child(NightSky.new())
	state = GameState.new()
	var loaded := state.load_from(save_path)
	hud = Hud.new()
	hud.state = state
	hud.bought.connect(func(_item: int) -> void: save_game())
	add_child(hud)

	var away := state.seconds_since_seen() if loaded else 0.0
	for a in args:
		if a.begins_with("--away="):  # за проба: като че ли те е нямало толкова секунди
			away = float(a.trim_prefix("--away="))
	if not loaded and not autotest:
		hud.show_toast("🔥 Пази огъня жив! Цепи дърва и приюти хора.")
	_welcome_back(away)

	if autotest:
		var tester: Node = preload("res://scripts/autotest.gd").new()
		tester.main = self
		add_child(tester)


func _process(delta: float) -> void:
	state.tick(delta)
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_EVERY:
		save_game()


func save_game() -> void:
	_autosave_t = 0.0
	state.save(save_path)


func _welcome_back(away: float) -> void:
	if away < MIN_AWAY:
		return
	var gained := state.apply_offline(away)
	if absf(gained) >= 1.0:
		hud.show_offline(away, gained)
	save_game()


func _notification(what: int) -> void:
	if state == null:
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:  # телефонът: връщане в играта
			_welcome_back(state.seconds_since_seen())

