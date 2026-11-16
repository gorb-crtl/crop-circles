class_name Menu
extends CanvasLayer
## Title screen, pause menu and options, drawn over the live field.
## Options: CRT strength, sound and music volume, cursor style, fullscreen,
## screen shake. Saved in user://settings.json (separate from the game save).

signal play(new_game: bool)
signal resumed
signal to_title

const SCREEN := Vector2(1280, 720)

var mode := "title"   # title, pause, options, hidden

var _root: Control
var _shade: ColorRect
var _title_box: Control
var _title_art: Control
var _pause_box: Control
var _options_box: Control
var _continue_btn: Button
var _back_to := "title"
var _cursor_buttons := {}
var _crt_label: Label
var _time := 0.0
var _saucer: Texture2D = preload("res://assets/sprites/saucer.png")
var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")
var _body: Font = preload("res://assets/fonts/PixelifySans.ttf")


func _ready() -> void:
	layer = 40
	_root = Control.new()
	_root.size = SCREEN
	_root.theme = ThemeBuilder.build()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_shade = ColorRect.new()
	_shade.size = SCREEN
	_shade.color = Color(0.01, 0.01, 0.03, 0.55)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_shade)
	_build_title()
	_build_pause()
	_build_options()
	show_title()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	match mode:
		"pause":
			resume()
		"options":
			_close_options()
		_:
			return
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return mode != "hidden"


func show_title() -> void:
	mode = "title"
	visible = true
	_continue_btn.visible = Game.has_save()
	_shade.color = Color(0.01, 0.01, 0.03, 0.45)
	_switch(_title_box)
	_title_art.visible = true


func show_pause() -> void:
	mode = "pause"
	visible = true
	_shade.color = Color(0.01, 0.01, 0.03, 0.7)
	_switch(_pause_box)
	_title_art.visible = false
	Music.duck(true)
	Sfx.play("pop")


func resume() -> void:
	mode = "hidden"
	visible = false
	Music.duck(false)
	Sfx.play("tick")
	resumed.emit()


func hide_menu() -> void:
	mode = "hidden"
	visible = false


func _switch(box: Control) -> void:
	for b in [_title_box, _pause_box, _options_box]:
		b.visible = b == box
	box.modulate.a = 0.0
	box.position.y += 10
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.2)
	tw.tween_property(box, "position:y", box.position.y - 10, 0.25)


func _process(delta: float) -> void:
	_time += delta
	if visible and _title_art.visible:
		_title_art.queue_redraw()


# ---------------------------------------------------------------- builders

func _menu_button(text: String, cb: Callable, width := 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 50)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(Color(0.07, 0.065, 0.09, 0.92), ThemeBuilder.BORDER, 2, 10.0))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.10, 0.16, 0.15, 0.96), Color(0.5, 1.0, 0.85), 2, 10.0))
	b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.06, 0.12, 0.11), Color(0.5, 1.0, 0.85), 2, 10.0))
	b.add_theme_color_override("font_hover_color", Color(0.7, 1.0, 0.9))
	b.pivot_offset = Vector2(width * 0.5, 25)
	b.mouse_entered.connect(func():
		Sfx.play("hover", -12.0)
		b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.pressed.connect(func():
		Sfx.play("pop")
		cb.call())
	return b


func _column(at: Vector2) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.position = at
	vb.add_theme_constant_override("separation", 12)
	_root.add_child(vb)
	return vb


func _build_title() -> void:
	_title_art = Control.new()
	_title_art.size = SCREEN
	_title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_art.draw.connect(_draw_title)
	_root.add_child(_title_art)
	_title_box = _column(Vector2(SCREEN.x * 0.5 - 150, 330))
	_continue_btn = _menu_button("CONTINUE", func(): play.emit(false))
	_title_box.add_child(_continue_btn)
	_title_box.add_child(_menu_button("NEW GAME", _ask_new_game))
	_title_box.add_child(_menu_button("OPTIONS", func(): _open_options("title")))
	_title_box.add_child(_menu_button("QUIT", func(): get_tree().quit()))


func _ask_new_game() -> void:
	if not Game.has_save():
		play.emit(true)
		return
	var box := _confirm_box("Start over?", "Your saved field, crew and Signal will be wiped.",
		func(): play.emit(true), func(): show_title())
	_switch(box)


func _confirm_box(title: String, body: String, yes: Callable, no: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(ThemeBuilder.BG_SOLID, ThemeBuilder.ACCENT, 2, 24.0))
	panel.position = Vector2(SCREEN.x * 0.5 - 240, 330)
	panel.custom_minimum_size = Vector2(480, 0)
	_root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", _font)
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var b := Label.new()
	b.text = body
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(b)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	hb.add_child(_menu_button("YES", func():
		panel.queue_free()
		yes.call(), 180))
	hb.add_child(_menu_button("NO", func():
		panel.queue_free()
		no.call(), 180))
	# Treat it like the other boxes so _switch can fade it.
	_title_box.visible = false
	return panel


func _build_pause() -> void:
	_pause_box = _column(Vector2(SCREEN.x * 0.5 - 150, 250))
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_override("font", _font)
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(0.6, 1.0, 0.88))
	t.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	t.add_theme_constant_override("outline_size", 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_box.add_child(t)
	_pause_box.add_child(_menu_button("RESUME", resume))
	_pause_box.add_child(_menu_button("OPTIONS", func(): _open_options("pause")))
	_pause_box.add_child(_menu_button("SAVE & QUIT TO TITLE", func(): to_title.emit()))
	_pause_box.add_child(_menu_button("QUIT GAME", func():
		Game.save_game()
		get_tree().quit()))


func _build_options() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.06, 0.055, 0.075, 0.97), Color(0.5, 1.0, 0.85), 2, 24.0))
	panel.position = Vector2(SCREEN.x * 0.5 - 280, 110)
	panel.custom_minimum_size = Vector2(560, 0)
	_root.add_child(panel)
	_options_box = panel
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var t := Label.new()
	t.text = "OPTIONS"
	t.add_theme_font_override("font", _font)
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color(0.6, 1.0, 0.88))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)

	_crt_label = Label.new()
	vb.add_child(_slider_row("CRT effect", Game.crt_amount, func(v):
		Game.crt_amount = v
		Game.apply_settings(), _crt_label))
	vb.add_child(_slider_row("Sound effects", Game.sfx_volume, func(v):
		Game.sfx_volume = v
		Sfx.play("coin", 0.0, 0.0, 60)))
	vb.add_child(_slider_row("Music", Game.music_volume, func(v):
		Game.music_volume = v
		Game.apply_settings()))

	var cl := Label.new()
	cl.text = "Cursor"
	cl.add_theme_color_override("font_color", ThemeBuilder.DIM)
	vb.add_child(cl)
	var cursors := HBoxContainer.new()
	cursors.add_theme_constant_override("separation", 8)
	vb.add_child(cursors)
	var hand: Texture2D = load("res://assets/sprites/cursor_hand.png")
	for style in Game.CURSORS:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(80, 70)
		b.tooltip_text = {"hand": "Alien hand", "dot": "Dot", "arrow": "Regular cursor", "triangle": "Triangle", "square": "Square", "hexagon": "Hexagon"}[style]
		var preview := Control.new()
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s: String = style
		preview.draw.connect(func():
			var at := Vector2(40, 30) if s != "arrow" else Vector2(32, 18)
			GameCursor.draw_shape(preview, s, at, 4.0, 0.0, hand, null)
			var name_w := _font.get_string_size(b.tooltip_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			preview.draw_string(_font, Vector2(40 - name_w * 0.5, 62), b.tooltip_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, ThemeBuilder.DIM))
		b.add_child(preview)
		b.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
		b.pressed.connect(func():
			Game.cursor = s
			Game.apply_settings()
			_refresh_cursor_buttons()
			Sfx.play("tick"))
		cursors.add_child(b)
		_cursor_buttons[style] = b
	_refresh_cursor_buttons()

	var checks := HBoxContainer.new()
	checks.add_theme_constant_override("separation", 30)
	vb.add_child(checks)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Game.fullscreen
	fs.toggled.connect(func(on):
		Game.fullscreen = on
		Game.apply_settings()
		Sfx.play("tick"))
	checks.add_child(fs)
	var sh := CheckButton.new()
	sh.text = "Screen shake"
	sh.button_pressed = Game.screen_shake
	sh.toggled.connect(func(on):
		Game.screen_shake = on
		Sfx.play("tick"))
	checks.add_child(sh)

	var keys := Label.new()
	keys.text = "Drag on the wheat to flatten it  ·  Tab: shop  ·  S: slot  ·  Esc: pause"
	keys.add_theme_color_override("font_color", ThemeBuilder.DIM)
	keys.add_theme_font_size_override("font_size", 14)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(keys)
	var back := _menu_button("BACK", _close_options, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(back)


func _slider_row(text: String, value: float, cb: Callable, value_label: Label = null) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := value_label if value_label else Label.new()
	pct.custom_minimum_size = Vector2(60, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_override("font", _font)
	pct.add_theme_font_size_override("font_size", 12)
	pct.add_theme_color_override("font_color", ThemeBuilder.ACCENT)
	pct.text = "%d%%" % int(round(value * 100))
	s.value_changed.connect(func(v):
		pct.text = "OFF" if v <= 0.001 else "%d%%" % int(round(v * 100))
		cb.call(v))
	if value <= 0.001:
		pct.text = "OFF"
	hb.add_child(s)
	hb.add_child(pct)
	return hb


func _refresh_cursor_buttons() -> void:
	for k in _cursor_buttons:
		(_cursor_buttons[k] as Button).set_pressed_no_signal(k == Game.cursor)


func _open_options(back: String) -> void:
	_back_to = back
	mode = "options"
	_title_art.visible = back == "title"
	_switch(_options_box)


func _close_options() -> void:
	Game.save_settings()
	if _back_to == "pause":
		mode = "pause"
		_switch(_pause_box)
	else:
		show_title()


# ---------------------------------------------------------------- title art

func _draw_title() -> void:
	var c := _title_art
	var cell := 4.0
	# Saucer drifting over the title with a beam.
	var sx := SCREEN.x * 0.5 + sin(_time * 0.6) * 140.0
	var sy := 70.0 + sin(_time * 1.7) * 6.0
	var sw := _saucer.get_width() * cell * 1.5
	var sh := _saucer.get_height() * cell * 1.5
	for k in 4:
		var w := 120.0 + k * 50.0 + sin(_time * 8.0 + k) * 6.0
		var col := Color(0.5, 1.0, 0.85, 0.05)
		c.draw_rect(Rect2(roundf((sx - w * 0.5) / cell) * cell, sy + sh * 0.6, roundf(w / cell) * cell, 230), col)
	c.draw_texture_rect(_saucer, Rect2(Vector2(roundf((sx - sw * 0.5) / cell) * cell, roundf(sy / cell) * cell), Vector2(sw, sh)), false)

	# Title: letters bob in a wave.
	var title := "CROP CIRCLES"
	var size := 72
	var w2 := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := (SCREEN.x - w2) * 0.5
	for i in title.length():
		var ch := title[i]
		var cw := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var bob := roundf(sin(_time * 2.5 - i * 0.45) * 6.0 / cell) * cell
		var base := Vector2(x, 228 + bob)
		c.draw_string_outline(_font, base + Vector2(0, 8), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 18, Color(0.0, 0.0, 0.02, 0.8))
		c.draw_string_outline(_font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(0.03, 0.05, 0.06))
		var glow := 0.5 + 0.5 * sin(_time * 3.0 - i * 0.6)
		c.draw_string(_font, base, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 0.80, 0.40).lerp(Color(0.55, 1.0, 0.85), glow * 0.6))
		x += cw
	var sub := "an idle game about extraterrestrial vandalism"
	var sw2 := _body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	c.draw_string_outline(_body, Vector2((SCREEN.x - sw2) * 0.5, 282), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 8, Color(0.02, 0.02, 0.04))
	c.draw_string(_body, Vector2((SCREEN.x - sw2) * 0.5, 282), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.85, 0.82, 0.75))
	if mode == "title":
		var foot := "v0.1  ·  placeholder art  ·  made in Godot"
		var fw := _font.get_string_size(foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		c.draw_string(_font, Vector2((SCREEN.x - fw) * 0.5, SCREEN.y - 18), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.6, 0.58, 0.55, 0.7))
