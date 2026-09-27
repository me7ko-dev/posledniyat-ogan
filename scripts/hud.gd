extends Control
## Екранът: дървата горе, лагерът в средата, бутонът за сечене и менюто с покупки.

signal bought(item: int)

const GameState := preload("res://scripts/game_state.gd")
const Fmt := preload("res://scripts/fmt.gd")
const CampView := preload("res://scripts/camp_view.gd")

const C_TEXT := Color("#f3e9dc")
const C_DIM := Color("#b9ad9c")
const C_GOOD := Color("#9be37a")
const C_BAD := Color("#ff7b6b")
const C_GOLD := Color("#ffd27a")
const C_ORANGE := Color("#d9731f")
const C_PANEL := Color(0.06, 0.07, 0.12, 0.8)

const ITEMS := [GameState.Item.RECRUIT, GameState.Item.FIRE, GameState.Item.AXE, GameState.Item.GLOVES]
const ICONS := {
	GameState.Item.RECRUIT: "👤", GameState.Item.FIRE: "🔥",
	GameState.Item.AXE: "🪓", GameState.Item.GLOVES: "🧤",
}
const CARD_REFRESH := 0.1  # колко често се обновява менюто (сек)
const MAX_COLUMN := 720.0  # най-голямата ширина на менюто

var state: GameState
var camp: CampView

var _margin: MarginContainer
var _wood: Label
var _rate: Label
var _people: Label
var _fire: Label
var _status: Label
var _tap_btn: Button
var _cards := {}  # предмет → {title, info, buy}
var _fx: Control  # слой за летящите „+5“ и съобщенията
var _toast: Control
var _card_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 20)
	add_child(_margin)
	resized.connect(_fit_column)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_margin.add_child(col)

	col.add_child(_top_bar())

	camp = CampView.new()
	camp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	camp.custom_minimum_size.y = 260
	camp.tapped.connect(_on_camp_tapped)
	col.add_child(camp)

	_status = _label("", 23, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_status)

	_tap_btn = Button.new()
	_tap_btn.custom_minimum_size.y = 104
	_tap_btn.add_theme_font_size_override("font_size", 36)
	_tap_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_tap_btn.pressed.connect(_on_tap_button)
	_style_button(_tap_btn, Color("#a8481a"))
	col.add_child(_tap_btn)

	for item: int in ITEMS:
		col.add_child(_card(item))

	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	_fit_column()
	_refresh()
	_refresh_cards()


## На широк прозорец (компютър) менюто стои в колона в средата, както на телефон.
func _fit_column() -> void:
	var side := maxf(20.0, (size.x - MAX_COLUMN) * 0.5)
	_margin.add_theme_constant_override("margin_left", int(side))
	_margin.add_theme_constant_override("margin_right", int(side))


func _process(delta: float) -> void:
	_refresh()
	_card_t += delta
	if _card_t >= CARD_REFRESH:
		_card_t = 0.0
		_refresh_cards()


# --- Действия (ползва ги и автоматичният тест) ---

## Удар с брадвата: дърва + летящо число на мястото на удара.
func do_tap(at: Vector2) -> void:
	var got := state.tap()
	_float_text("+%s 🪵" % Fmt.rate(got), at)


func try_buy(item: int) -> bool:
	if not state.buy(item):
		return false
	match item:
		GameState.Item.RECRUIT:
			show_toast("👤 %s се присъедини към лагера!" % state.names[-1])
		GameState.Item.FIRE:
			camp.flare()
			show_toast("🔥 Огънят пламна! Вече има места за %d души." % state.seats())
	bought.emit(item)
	_refresh_cards()
	return true


func show_toast(text: String) -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	var panel := PanelContainer.new()
	panel.add_child(_label(text, 24, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.add_child(panel)
	panel.reset_size()
	panel.position = Vector2((size.x - panel.size.x) * 0.5, camp.global_position.y + 8.0)
	panel.modulate.a = 0.0
	_toast = panel
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)


## Прозорецът „Докато те нямаше“.
func show_offline(seconds: float, gained: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = theme
	layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	col.add_child(_label("🌙 Докато те нямаше", 40, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_label(Fmt.duration(seconds), 28, C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if gained >= 0.0:
		col.add_child(_label("оцелелите насякоха\n+%s 🪵" % Fmt.num(gained), 36, C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		col.add_child(_label("огънят изгори %s 🪵.\nТрябват още хора!" % Fmt.num(-gained), 32, C_BAD, HORIZONTAL_ALIGNMENT_CENTER))
	if seconds > GameState.OFFLINE_CAP:
		col.add_child(_label("(лагерът работи сам най-много 8 часа)", 22, C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := Button.new()
	ok.text = "Супер!"
	ok.custom_minimum_size = Vector2(0, 90)
	ok.add_theme_font_size_override("font_size", 34)
	_style_button(ok, C_ORANGE)
	ok.pressed.connect(layer.queue_free)
	col.add_child(ok)


# --- Обновяване ---

func _refresh() -> void:
	_wood.text = "🪵 " + Fmt.num(state.wood)
	var net := state.net_rate()
	_rate.text = "%s%s на секунда" % ["+" if net >= 0.0 else "−", Fmt.rate(absf(net))]
	_rate.add_theme_color_override("font_color", C_GOOD if net >= 0.0 else C_BAD)
	_people.text = "👤 %d/%d" % [state.survivor_count(), state.seats()]
	_fire.text = "🔥 огън ниво %d" % state.fire_level
	if state.is_cold():
		_status.text = "❄ Огънят гасне! Приюти хора или цепи дърва."
		_status.add_theme_color_override("font_color", C_BAD)
	else:
		_status.text = "Огънят изгаря %s 🪵 на секунда" % Fmt.rate(state.burn_rate())
		_status.add_theme_color_override("font_color", C_DIM)
	_tap_btn.text = "🪓 Цепи дърва   +%s" % Fmt.rate(state.tap_power())
	camp.fire_level = state.fire_level
	camp.cold = state.is_cold()
	camp.survivors = state.survivor_count()


func _refresh_cards() -> void:
	for item: int in ITEMS:
		var ui: Dictionary = _cards[item]
		var next = state.preview(item)
		var title: Label = ui.title
		var info: Label = ui.info
		var buy: Button = ui.buy
		match item:
			GameState.Item.RECRUIT:
				title.text = "Приюти оцелял"
				info.text = "Сечене: %s → %s 🪵/сек" % [Fmt.rate(state.gather_rate()), Fmt.rate(next.gather_rate())]
			GameState.Item.FIRE:
				title.text = "Разпали огъня · ниво %d" % state.fire_level
				info.text = "Места: %d → %d · сечене +15%%\nГори: %s → %s 🪵/сек" % [
					state.seats(), next.seats(), Fmt.rate(state.burn_rate()), Fmt.rate(next.burn_rate())]
			GameState.Item.AXE:
				title.text = "Остри брадви · ниво %d" % state.axe_level
				info.text = "На човек: %s → %s 🪵/сек" % [Fmt.rate(state.rate_per_survivor()), Fmt.rate(next.rate_per_survivor())]
			GameState.Item.GLOVES:
				title.text = "Здрави ръкавици · ниво %d" % state.gloves_level
				info.text = "Удар: +%s → +%s 🪵" % [Fmt.rate(state.tap_power()), Fmt.rate(next.tap_power())]
		if item == GameState.Item.RECRUIT and not state.has_seat():
			info.text = "Няма място. Разпали огъня!"
			buy.text = "Пълно"
			buy.disabled = true
		else:
			buy.text = "🪵 " + Fmt.num(state.cost(item))
			buy.disabled = not state.can_buy(item)


# --- Строене на екрана ---

func _top_bar() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_wood = _label("", 50, C_TEXT)
	left.add_child(_wood)
	_rate = _label("", 24, C_GOOD)
	left.add_child(_rate)
	var right := VBoxContainer.new()
	row.add_child(right)
	_people = _label("", 36, C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_people)
	_fire = _label("", 24, C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_fire)
	return panel


func _card(item: int) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon := _label(ICONS[item], 46, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	icon.custom_minimum_size.x = 64
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var title := _label("", 27, C_TEXT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(title)
	var info := _label("", 21, C_DIM)
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(info)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(170, 84)
	buy.add_theme_font_size_override("font_size", 28)
	buy.pressed.connect(try_buy.bind(item))
	_style_button(buy, C_ORANGE)
	row.add_child(buy)

	_cards[item] = {"title": title, "info": info, "buy": buy}
	return panel


func _on_camp_tapped(local_pos: Vector2) -> void:
	do_tap(camp.global_position + local_pos)
	camp.burst(local_pos)


func _on_tap_button() -> void:
	do_tap(_tap_btn.global_position + Vector2(_tap_btn.size.x * randf_range(0.3, 0.7), 0))
	camp.burst_fire()


func _float_text(text: String, at: Vector2) -> void:
	var l := _label(text, 32, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	_fx.add_child(l)
	l.reset_size()
	l.position = at - l.size * 0.5 + Vector2(randf_range(-30, 30), 0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 120.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var panel := StyleBoxFlat.new()
	panel.bg_color = C_PANEL
	panel.set_corner_radius_all(18)
	panel.set_content_margin_all(16)
	panel.border_color = Color(1.0, 0.6, 0.3, 0.14)
	panel.set_border_width_all(1)
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


func _style_button(b: Button, base: Color) -> void:
	var colors := {
		"normal": base, "hover": base.lightened(0.12), "pressed": base.darkened(0.2),
		"disabled": Color(0.22, 0.22, 0.28, 0.85),
	}
	for st: String in colors:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[st]
		sb.set_corner_radius_all(14)
		sb.set_content_margin_all(10)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", C_DIM)
	b.focus_mode = Control.FOCUS_NONE
