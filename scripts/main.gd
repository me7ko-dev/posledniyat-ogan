extends Node3D
## „Последният огън“ — idle arcade в снежна гора (като Pizza Ready / Burger Please).
## Тичаш с джойстика, брадвата сече сама, носиш дървата в огъня, пътниците се топлят и плащат,
## а с монетите строиш на квадратите: пейки, раница, дървари, палатка, нова гора, голям огън.

const B := preload("res://scripts/balance.gd")
const World := preload("res://scripts/world.gd")
const Models := preload("res://scripts/models.gd")
const Fx := preload("res://scripts/fx.gd")
const Fmt := preload("res://scripts/fmt.gd")
const Player := preload("res://scripts/player.gd")
const Fire := preload("res://scripts/fire.gd")
const TreeNode := preload("res://scripts/tree_node.gd")
const Traveller := preload("res://scripts/traveller.gd")
const Helper := preload("res://scripts/helper.gd")
const CoinPile := preload("res://scripts/coin_pile.gd")
const Pad := preload("res://scripts/pad.gd")
const Hud := preload("res://scripts/hud.gd")

const SAVE_PATH := "user://save.json"
const TEST_SAVE_PATH := "user://autotest_save.json"
const SAVE_VERSION := 2
const AUTOSAVE_EVERY := 10.0
const MIN_AWAY := 60.0
const CAM_OFFSET := Vector3(0, 10.4, 7.6)
const PADS_VISIBLE := 2
const HELPER_MODELS := ["character-male-c", "character-female-d"]
const BUILT_TEXT := {
	"bench": "🪵 Още две пейки — идват повече пътници!",
	"backpack": "🎒 Раница: вече носиш 12 цепеници!",
	"helper": "🪓 Дърварят сече и носи дърва в огъня!",
	"tent": "⛺ Палатка: пътниците плащат двойно!",
	"axe": "🪓 Острата брадва сече двойно по-бързо!",
	"helper2": "🪓 Втори дървар!",
	"forest": "🌲 Нова гора на изток!",
	"bigfire": "🔥 Голям огън: още пейки и повече пътници!",
}


class Seat:
	var angle := 0.0
	var pos := Vector3.ZERO
	var who: Node = null
	var pile: Node3D = null


var save_path := SAVE_PATH
var coins := 0
var built: Array[String] = []
var pad_paid := {}  # id → вече платени монети (за записа)
var tutorial := 0
var player: Player
var fire: Fire
var trees: Array[TreeNode] = []
var seats: Array[Seat] = []
var travellers: Array[Node] = []
var helpers: Array[Node] = []
var pads := {}  # id → Pad (само видимите)
var hud: Hud
var camera: Camera3D
var _snow: GPUParticles3D
var _arrow: Label3D
var _arrow_target = null
var _spawn_t := 1.0
var _save_t := 0.0
var _clock := 0.0
var _paused_at := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var autotest := "--autotest" in args
	if autotest:
		save_path = TEST_SAVE_PATH
	if autotest or "--reset" in args:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	World.build(self)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 52.0
	camera.rotation_degrees.x = -54.0
	add_child(camera)
	_snow = World.snow()
	add_child(_snow)

	fire = Fire.new()
	add_child(fire)
	for p: Vector3 in B.TREES:
		_add_tree(p, false)
	for a: float in B.SEATS_BASE:
		_add_seat(a, false)
	player = Player.new()
	player.main = self
	player.position = B.PLAYER_START
	add_child(player)
	_arrow = _make_arrow()
	add_child(_arrow)
	hud = Hud.new()
	hud.main = self
	add_child(hud)

	var away := _load()
	for a in args:
		if a.begins_with("--away="):  # за проба: като че ли те е нямало толкова секунди
			away = float(a.trim_prefix("--away="))
	_refresh_pads()
	camera.position = player.position + CAM_OFFSET
	if away >= MIN_AWAY:
		_welcome_back(away)
	elif away < 0.0 and not autotest:
		hud.show_toast("🔥 Пази огъня жив!\nСечи дърва и топли пътниците.", 3.5)

	if autotest:
		var tester: Node = preload("res://scripts/autotest.gd").new()
		tester.main = self
		add_child(tester)


func _process(delta: float) -> void:
	_clock += delta
	camera.position = camera.position.lerp(player.position + CAM_OFFSET, 1.0 - exp(-delta * 6.0))
	_snow.position = player.position + Vector3(0, 10, 0)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = B.SPAWN_EVERY_BIG if fire.big else B.SPAWN_EVERY
		_spawn_traveller()
	_update_tutorial()
	_update_arrow()
	_save_t += delta
	if _save_t >= AUTOSAVE_EVERY:
		save_game()


# ---------- светът ----------

func _add_tree(p: Vector3, animate: bool) -> void:
	var t := TreeNode.new()
	t.model = "tree-tall" if randf() < 0.4 else "tree"
	t.position = p
	add_child(t)
	trees.append(t)
	if animate:
		Fx.pop(t, 0.5)


func _add_seat(angle: float, animate: bool) -> void:
	var s := Seat.new()
	s.angle = angle
	var a := deg_to_rad(angle)
	var radial := Vector3(sin(a), 0.0, cos(a))
	s.pos = radial * B.SEAT_R
	var bench := Models.prop("tree-log-small")
	bench.position = s.pos
	bench.rotation.y = a + PI / 2.0
	add_child(bench)
	var pile := CoinPile.new()
	pile.position = radial * (B.SEAT_R + 0.95)
	add_child(pile)
	s.pile = pile
	seats.append(s)
	if animate:
		Fx.pop(bench)


func _add_helper(at: Vector3) -> void:
	var h := Helper.new()
	h.main = self
	h.model = HELPER_MODELS[helpers.size() % HELPER_MODELS.size()]
	h.position = at
	add_child(h)
	helpers.append(h)


func _make_arrow() -> Label3D:
	var a := Label3D.new()
	a.text = "▼"
	a.font_size = 150
	a.outline_size = 26
	a.pixel_size = 0.006
	a.modulate = Color("#ffd24a")
	a.outline_modulate = Color(0.3, 0.16, 0.0, 0.95)
	a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a.no_depth_test = true
	a.render_priority = 5
	a.visible = false
	return a


## Движение без минаване през огъня и дърветата.
func keep_in_bounds(p: Vector3, r: float, around_trees := true) -> Vector3:
	p.x = clampf(p.x, B.BOUNDS.position.x, B.BOUNDS.end.x)
	p.z = clampf(p.z, B.BOUNDS.position.y, B.BOUNDS.end.y)
	p = _push_out(p, fire.global_position, 0.75 + r)
	if around_trees:
		for t in trees:
			if t.has_logs():
				p = _push_out(p, t.global_position, 0.3 + r)
	return p


func _push_out(p: Vector3, c: Vector3, dist: float) -> Vector3:
	var d := Vector3(p.x - c.x, 0.0, p.z - c.z)
	var l := d.length()
	if l < dist:
		if l < 0.001:
			d = Vector3.BACK
			l = 1.0
		p += d / l * (dist - l)
	return p


func nearest_tree(pos: Vector3, max_dist: float) -> TreeNode:
	var best: TreeNode = null
	var bd := max_dist
	for t in trees:
		if not t.has_logs():
			continue
		var d := _flat(pos, t.global_position)
		if d <= bd:
			bd = d
			best = t
	return best


func free_tree_for(who: Node, pos: Vector3) -> TreeNode:
	var best: TreeNode = null
	var bd := INF
	for t in trees:
		if not t.has_logs() or (t.reserved != null and t.reserved != who):
			continue
		var d := _flat(pos, t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func nearest_pile(pos: Vector3, max_dist: float) -> Node3D:
	for s in seats:
		if s.pile.count > 0 and _flat(pos, s.pile.global_position) <= max_dist:
			return s.pile
	return null


func pad_under(pos: Vector3) -> Pad:
	for id in pads:
		var p: Pad = pads[id]
		if absf(pos.x - p.position.x) <= B.PAD_RANGE and absf(pos.z - p.position.z) <= B.PAD_RANGE:
			return p
	return null


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------- летящи неща ----------

func fly_log_to_stack(from: Vector3, stack: Node3D) -> void:
	stack.incoming += 1
	var piece := Models.prop("resource-wood", 1.15)
	add_child(piece)
	Fx.fly(piece, from, stack.top_global, 0.32, 0.8).finished.connect(func() -> void:
		piece.queue_free()
		if is_instance_valid(stack):
			stack.incoming -= 1
			stack.add())


func fly_log_to_fire(from: Vector3) -> void:
	fire.incoming += 1
	var piece := Models.prop("resource-wood", 1.15)
	add_child(piece)
	var to := fire.global_position + Vector3(0, 0.3, 0)
	Fx.fly(piece, from, func() -> Vector3: return to, 0.35, 1.0).finished.connect(func() -> void:
		piece.queue_free()
		fire.add_fuel(B.FUEL_PER_LOG))


func fly_coins_to_player(from: Vector3, n: int) -> void:
	var c := Models.coin()
	add_child(c)
	Fx.fly(c, from, func() -> Vector3: return player.global_position + Vector3(0, 1.3, 0), 0.28, 0.9).finished.connect(func() -> void:
		c.queue_free()
		coins += n
		hud.bump_coins()
		if tutorial == 2:
			tutorial = 3)


func fly_coins_to_pad(from: Vector3, pad: Pad, n: int) -> void:
	var c := Models.coin()
	add_child(c)
	var to := pad.global_position + Vector3(0, 0.15, 0)
	Fx.fly(c, from, func() -> Vector3: return to, 0.3, 0.9).finished.connect(func() -> void:
		c.queue_free()
		if not is_instance_valid(pad):
			coins += n
			return
		pad.receive(n)
		if pad.done() and not (pad.id in built):
			_build(pad))


# ---------- пътниците ----------

func _spawn_traveller() -> void:
	var free: Array[Seat] = []
	for s in seats:
		if s.who == null:
			free.append(s)
	if free.is_empty():
		return
	var seat: Seat = free.pick_random()
	var models: Array = Models.CHARACTERS.filter(func(m: String) -> bool:
		return m != Player.MODEL and not (m in HELPER_MODELS))
	var t := Traveller.new()
	t.main = self
	t.seat = seat
	t.model = models.pick_random()
	t.position = B.SPAWN_POS
	seat.who = t
	add_child(t)
	travellers.append(t)


func pay_amount() -> int:
	return B.PAY + (B.PAY_TENT if "tent" in built else 0)


func traveller_pays(t: Node3D) -> void:
	var pile: Node3D = t.seat.pile
	var from := t.global_position + Vector3(0, 1.4, 0)
	for i in pay_amount():
		var c := Models.coin()
		add_child(c)
		Fx.fly(c, from, pile.top_global, 0.35 + i * 0.06, 1.0).finished.connect(func() -> void:
			c.queue_free()
			pile.add(1))
	t.avatar.play_once("emote-yes")


func free_seat(seat: Seat) -> void:
	seat.who = null


func traveller_gone(t: Node) -> void:
	travellers.erase(t)


func path_to_seat(seat: Seat) -> Array[Vector3]:
	var pts := _arc(B.ENTRY_ANGLE, seat.angle, B.RING_R)
	pts.append(seat.pos)
	return pts


func path_from_seat(seat: Seat) -> Array[Vector3]:
	var pts := _arc(seat.angle, B.EXIT_ANGLE, B.RING_R)
	pts.append(B.EXIT_POS)
	return pts


## Точки по кръга около лагера — пътниците не минават през огъня и пейките.
func _arc(a0: float, a1: float, r: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var d := wrapf(a1 - a0, -180.0, 180.0)
	var n := maxi(1, ceili(absf(d) / 25.0))
	for i in n + 1:
		var a := deg_to_rad(a0 + d * i / n)
		pts.append(Vector3(sin(a) * r, 0.0, cos(a) * r))
	return pts


# ---------- строене ----------

func _refresh_pads() -> void:
	var shown := 0
	for d: Dictionary in B.PADS:
		if d.id in built:
			continue
		if shown >= PADS_VISIBLE:
			break
		shown += 1
		if pads.has(d.id):
			continue
		var p := Pad.new()
		p.id = d.id
		p.title = d.name
		p.icon = d.icon
		p.cost = d.cost
		p.paid = int(pad_paid.get(d.id, 0))
		p.position = d.pos
		add_child(p)
		pads[d.id] = p
		Fx.pop(p, 0.4)


func _pad_pos(id: String) -> Vector3:
	for d: Dictionary in B.PADS:
		if d.id == id:
			return d.pos
	return Vector3.ZERO


func _build(pad: Pad) -> void:
	built.append(pad.id)
	pad_paid.erase(pad.id)
	pads.erase(pad.id)
	var tw := pad.create_tween()
	tw.tween_property(pad, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(pad.queue_free)
	_apply(pad.id, false, pad.position)
	hud.show_toast(BUILT_TEXT.get(pad.id, "Построено!"))
	if tutorial == 3:
		tutorial = 4
	_refresh_pads()
	if pads.is_empty():
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			hud.show_toast("🏕️ Лагерът е готов!\nСкоро: нощи, вълци и нови места.", 4.0))
	save_game()


func _apply(id: String, instant: bool, at: Vector3) -> void:
	match id:
		"bench":
			for a: float in B.SEATS_BENCH:
				_add_seat(a, not instant)
		"backpack":
			player.stack.capacity = B.CAPACITY_BACKPACK
		"helper", "helper2":
			_add_helper(at)
		"tent":
			var t := Models.prop("tent-canvas", 1.4)
			t.position = at + Vector3(-0.3, 0, -0.9)
			t.rotation.y = 0.5
			add_child(t)
			if not instant:
				Fx.pop(t)
		"axe":
			player.sharp = true
			player.avatar.hold_axe("tool-axe-upgraded")
		"forest":
			for p: Vector3 in B.TREES_FOREST:
				_add_tree(p, not instant)
		"bigfire":
			fire.make_big()
			for a: float in B.SEATS_BIG:
				_add_seat(a, not instant)


# ---------- подсказки ----------

func on_player_chop() -> void:
	if tutorial == 0:
		tutorial = 1


func on_player_feed() -> void:
	if tutorial == 1:
		tutorial = 2


func _update_tutorial() -> void:
	var text := ""
	_arrow_target = null
	match tutorial:
		0:
			text = "Иди до дърво — брадвата сече сама"
			_arrow_target = nearest_tree(player.global_position, 100.0)
		1:
			text = "Занеси дървата на огъня"
			_arrow_target = fire
		2:
			text = "Пътниците се топлят и плащат.\nСъбери монетите!"
			var pile := fullest_pile()
			_arrow_target = pile if pile != null else fire
		3:
			text = "Стъпи на квадрата, за да построиш"
			for d: Dictionary in B.PADS:
				if pads.has(d.id):
					_arrow_target = pads[d.id]
					break
		_:
			if fire.fuel < 12.0 and helpers.is_empty():
				text = "🔥 Огънят гасне! Донеси дърва" if fire.burning() else "❄ Огънят угасна! Донеси дърва"
				_arrow_target = fire
	hud.set_hint(text)


func _update_arrow() -> void:
	if _arrow_target == null or not is_instance_valid(_arrow_target):
		_arrow.visible = false
		return
	var h := 1.6
	if _arrow_target is TreeNode:
		h = 4.4
	elif _arrow_target is Fire:
		h = 3.1
	elif _arrow_target is Pad:
		h = 2.2
	_arrow.visible = true
	_arrow.global_position = _arrow_target.global_position + Vector3(0, h + sin(_clock * 5.0) * 0.18, 0)


func fullest_pile() -> Node3D:
	var best: Node3D = null
	for s in seats:
		if s.pile.count > 0 and (best == null or s.pile.count > best.count):
			best = s.pile
	return best


func total_pile() -> int:
	var n := 0
	for s in seats:
		n += s.pile.count
	return n


func fmt_num(x: float) -> String:
	return Fmt.num(x)


# ---------- запис и време без теб ----------

func save_game() -> void:
	_save_t = 0.0
	for id in pads:
		pad_paid[id] = pads[id].paid + pads[id].incoming
	var d := {
		"v": SAVE_VERSION, "coins": coins, "built": built, "paid": pad_paid, "fuel": fire.fuel,
		"tutorial": tutorial, "x": player.position.x, "z": player.position.z,
		"last_seen": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()


## Зарежда записа. Връща колко секунди те е нямало (или -1, ако няма запис).
func _load() -> float:
	if not FileAccess.file_exists(save_path):
		return -1.0
	var d = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != SAVE_VERSION:
		return -1.0  # стар запис от първата версия — започваме наново
	coins = int(d.get("coins", 0))
	tutorial = int(d.get("tutorial", 0))
	fire.fuel = float(d.get("fuel", B.FUEL_START))
	pad_paid = d.get("paid", {})
	for id in d.get("built", []):
		var s := str(id)
		if s in built:
			continue
		built.append(s)
		_apply(s, true, _pad_pos(s))
	player.position = keep_in_bounds(Vector3(float(d.get("x", 0.0)), 0.0, float(d.get("z", 3.6))), 0.45)
	return maxf(0.0, Time.get_unix_time_from_system() - float(d.get("last_seen", 0.0)))


func offline_gain(away: float) -> int:
	if helpers.is_empty():
		return 0
	var per_sec := seats.size() * pay_amount() / (B.WARM_TIME + 8.0)
	return int(minf(away, B.OFFLINE_MAX) * per_sec * B.OFFLINE_SHARE)


func _welcome_back(away: float) -> void:
	var gain := offline_gain(away)
	if helpers.is_empty():
		fire.fuel = maxf(0.0, fire.fuel - away)
	if gain > 0:
		coins += gain
		hud.show_toast("Докато те нямаше (%s)\nдърварите пазиха огъня: +%s 🪙" % [Fmt.duration(minf(away, B.OFFLINE_MAX)), fmt_num(gain)], 4.5)
	elif not fire.burning():
		hud.show_toast("❄ Огънят угасна, докато те нямаше.\nЗапали го пак с дърва!", 4.0)
	save_game()


func _notification(what: int) -> void:
	if fire == null:
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()
		NOTIFICATION_APPLICATION_PAUSED:
			_paused_at = Time.get_unix_time_from_system()
			save_game()
		NOTIFICATION_APPLICATION_RESUMED:  # телефонът: връщане в играта
			if _paused_at > 0.0:
				var away := Time.get_unix_time_from_system() - _paused_at
				_paused_at = 0.0
				if away >= MIN_AWAY:
					_welcome_back(away)
