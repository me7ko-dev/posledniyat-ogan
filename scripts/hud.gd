extends CanvasLayer
## Екранът отгоре: монети, дърва в ръцете, подсказка, съобщения и джойстикът.
## Джойстикът се появява там, където докоснеш (или натиснеш с мишката), и следва пръста.
## На компютър може и със стрелките / WASD.

const JOY_R := 95.0
const KNOB_R := 42.0

var main: Node
var _coins: Label
var _logs: Label
var _hint_box: PanelContainer
var _hint: Label
var _toast: Label
var _toast_tw: Tween
var _joy: Control
var joy_on := false
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var _touch_index := -1
var _coin_bump: Tween


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_joy = JoyView.new()
	_joy.hud = self
	_joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_joy)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 24
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_coins = _pill(top, "🪙 0", 46)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	_logs = _pill(top, "🪵 0/6", 36)

	_hint_box = PanelContainer.new()
	_hint_box.add_theme_stylebox_override("panel", _box(Color(0.05, 0.07, 0.14, 0.72), 22))
	_hint_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_box.offset_top = 124
	_hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_box)
	_hint = _label(34, Color("#ffe7b0"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_box.add_child(_hint)
	_hint_box.visible = false

	_toast = _label(40, Color.WHITE)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = -330
	_toast.offset_bottom = -330
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.custom_minimum_size = Vector2(620, 0)
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _pill(parent: Control, text: String, size: int) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(Color(0.05, 0.07, 0.14, 0.7), 18))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := _label(size, Color.WHITE)
	l.text = text
	p.add_child(l)
	return l


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(26)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.5
	s.content_margin_bottom = pad * 0.5
	return s


func _process(_delta: float) -> void:
	var p = main.player
	_coins.text = "🪙 %s" % main.fmt_num(main.coins)
	_logs.text = "🪵 %d/%d" % [p.stack.count(), p.stack.capacity]
	var k := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if joy_on:
		p.input_dir = (joy_knob - joy_center) / JOY_R
	else:
		p.input_dir = k.normalized() if k != Vector2.ZERO else Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _touch_index == -1:
			_touch_index = e.index
			_joy_start(e.position)
		elif not e.pressed and e.index == _touch_index:
			_touch_index = -1
			_joy_stop()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _touch_index:
			_joy_move(e.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_joy_start(e.position)
			else:
				_joy_stop()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and joy_on and _touch_index == -1:
		_joy_move((event as InputEventMouseMotion).position)


func _joy_start(pos: Vector2) -> void:
	joy_on = true
	joy_center = pos
	joy_knob = pos
	_joy.queue_redraw()


func _joy_move(pos: Vector2) -> void:
	var d := pos - joy_center
	if d.length() > JOY_R:
		joy_center = pos - d.normalized() * JOY_R  # основата следва пръста
	joy_knob = pos
	_joy.queue_redraw()


func _joy_stop() -> void:
	joy_on = false
	_joy.queue_redraw()


func set_hint(text: String) -> void:
	_hint_box.visible = text != ""
	if _hint.text != text:
		_hint.text = text


func show_toast(text: String, sec := 2.6) -> void:
	_toast.text = text
	if _toast_tw:
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast.scale = Vector2.ONE
	_toast_tw = create_tween()
	_toast_tw.tween_interval(sec)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.5)


func bump_coins() -> void:
	var p: Control = _coins.get_parent()
	p.pivot_offset = p.size / 2.0
	if _coin_bump:
		_coin_bump.kill()
	p.scale = Vector2(1.12, 1.12)
	_coin_bump = create_tween()
	_coin_bump.tween_property(p, "scale", Vector2.ONE, 0.15)


class JoyView extends Control:
	var hud

	func _draw() -> void:
		if not hud.joy_on:
			return
		draw_circle(hud.joy_center, JOY_R, Color(1, 1, 1, 0.1))
		draw_arc(hud.joy_center, JOY_R, 0.0, TAU, 56, Color(1, 1, 1, 0.45), 4.0, true)
		draw_circle(hud.joy_knob, KNOB_R, Color(1, 1, 1, 0.55))
