class_name SlotMachine
extends Control
## The Mothership Slot: a full-screen popup. Bet a slice of your money, pull
## the lever, three reels spin. Match symbols to win. Three cows = the cows
## win. After a win you can go double-or-nothing.
## Odds and payouts are in WEIGHTS / TRIPLE / PAIR below.

signal prize(kind: String)
signal closed

const SYMBOLS: Array = ["wheat", "cow", "alien", "circle", "ufo", "star"]
const WEIGHTS := {"wheat": 30, "cow": 20, "alien": 18, "circle": 14, "ufo": 11, "star": 7}
const TRIPLE := {"star": 50.0, "ufo": 20.0, "circle": 10.0, "alien": 6.0, "wheat": 4.0, "cow": 0.0}
const PAIR := {"star": 3.0, "ufo": 2.5, "circle": 2.0, "alien": 1.5, "wheat": 1.2, "cow": 0.0}
const BETS: Array = [0.1, 0.25, 0.5, 1.0]
const STRIP_LEN := 30
const SYM_PX := 80.0
const PANEL := Vector2(560, 570)

var spinning := false
var bet_frac := 0.1

var _icons := {}
var _strips: Array = []      # per reel: Array of symbol names
var _offsets: Array = [0.0, 0.0, 0.0]
var _speeds: Array = [0.0, 0.0, 0.0]
var _stopped: Array = [true, true, true]
var _result: Array = ["star", "star", "star"]
var _panel: Control
var _reels: Control
var _msg: Label
var _bet_buttons: Array = []
var _spin_btn: Button
var _double_btn: Button
var _collect_btn: Button
var _lever := 0.0
var _flash := 0.0
var _win_glow := 0.0
var _time := 0.0
var _last_bet := 0.0
var _pending_win := 0.0
var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")


func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for s in SYMBOLS:
		_icons[s] = load("res://assets/icons/sym_%s.png" % s)
	for r in 3:
		var strip: Array = []
		for i in STRIP_LEN:
			strip.append(_roll())
		_strips.append(strip)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.72)
	dim.size = size
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	_panel = Control.new()
	_panel.size = PANEL
	_panel.position = (size - PANEL) * 0.5
	_panel.draw.connect(_draw_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_reels = Control.new()
	_reels.position = Vector2(80, 112)
	_reels.size = Vector2(400, 150)
	_reels.clip_contents = true
	_reels.draw.connect(_draw_reels)
	_reels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_reels)

	_msg = Label.new()
	_msg.add_theme_font_override("font", _font)
	_msg.add_theme_font_size_override("font_size", 16)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.position = Vector2(20, 278)
	_msg.size = Vector2(PANEL.x - 40, 26)
	_msg.add_theme_color_override("font_outline_color", Color.BLACK)
	_msg.add_theme_constant_override("outline_size", 6)
	_panel.add_child(_msg)

	var bets := HBoxContainer.new()
	bets.position = Vector2(40, 318)
	bets.size = Vector2(PANEL.x - 80, 40)
	bets.add_theme_constant_override("separation", 8)
	_panel.add_child(bets)
	for f in BETS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(112, 40)
		b.toggle_mode = true
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_set_bet.bind(f))
		b.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
		bets.add_child(b)
		_bet_buttons.append(b)

	_spin_btn = _big_button("PULL THE LEVER", Vector2(140, 372), Vector2(280, 56))
	_spin_btn.pressed.connect(spin)
	_double_btn = _big_button("DOUBLE OR NOTHING", Vector2(40, 372), Vector2(230, 56))
	_double_btn.pressed.connect(_double)
	_collect_btn = _big_button("COLLECT", Vector2(290, 372), Vector2(230, 56))
	_collect_btn.pressed.connect(_collect)
	var close := Button.new()
	close.text = "X"
	close.tooltip_text = "Close (Esc)"
	close.position = Vector2(PANEL.x - 46, 14)
	close.size = Vector2(32, 32)
	close.pressed.connect(close_slot)
	_panel.add_child(close)
	_show_double(false)
	_set_bet(0.1)
	visible = false
	Game.changed.connect(_refresh_bets)


func _big_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", ThemeBuilder.box(Color(0.42, 0.12, 0.14), Color(1.0, 0.75, 0.35), 2, 8.0))
	b.add_theme_stylebox_override("hover", ThemeBuilder.box(Color(0.6, 0.18, 0.18), Color(1.0, 0.9, 0.5), 2, 8.0))
	b.add_theme_stylebox_override("pressed", ThemeBuilder.box(Color(0.3, 0.08, 0.1), Color(1.0, 0.9, 0.5), 2, 8.0))
	b.add_theme_stylebox_override("disabled", ThemeBuilder.box(Color(0.15, 0.08, 0.1), Color(0.35, 0.25, 0.2), 2, 8.0))
	b.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
	_panel.add_child(b)
	return b


func open_slot() -> void:
	visible = true
	_msg.text = "Feeling lucky, earthling?"
	_msg.add_theme_color_override("font_color", ThemeBuilder.TEXT)
	_refresh_bets()
	_panel.scale = Vector2(0.85, 0.85)
	_panel.pivot_offset = PANEL * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.25)
	Sfx.play("pop")


func close_slot() -> void:
	if spinning:
		return
	if _pending_win > 0.0:
		_collect()
	visible = false
	Sfx.play("tick", -6.0)
	closed.emit()


func _on_dim_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close_slot()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not visible or not k or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ESCAPE:
		close_slot()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_SPACE and not spinning and _pending_win <= 0.0:
		spin()
		get_viewport().set_input_as_handled()


func max_bet() -> float:
	return maxf(50.0, Game.season_goal() * 0.25)


func bet_amount(f: float) -> float:
	return floorf(minf(Game.money * f, max_bet()))


func _set_bet(f: float) -> void:
	bet_frac = f
	Sfx.play("tick", -8.0)
	_refresh_bets()


func _refresh_bets() -> void:
	if _bet_buttons.is_empty():
		return
	for i in BETS.size():
		var f: float = BETS[i]
		var b: Button = _bet_buttons[i]
		var label := "ALL IN" if f >= 1.0 else "%d%%" % int(f * 100)
		var capped := Game.money * f > max_bet()
		b.text = "%s\n$%s%s" % [label, Game.fmt(bet_amount(f)), " MAX" if capped else ""]
		b.button_pressed = is_equal_approx(f, bet_frac)
		b.disabled = spinning or _pending_win > 0.0
	_spin_btn.disabled = spinning or bet_amount(bet_frac) < 1.0


func _roll() -> String:
	var total := 0
	for s in SYMBOLS:
		total += WEIGHTS[s]
	var r := randi() % total
	for s in SYMBOLS:
		r -= WEIGHTS[s]
		if r < 0:
			return s
	return "wheat"


func spin() -> void:
	if spinning:
		return
	var bet := bet_amount(bet_frac)
	if bet < 1.0 or not Game.spend(bet):
		Sfx.play("deny")
		return
	_last_bet = bet
	spinning = true
	Game.stats["spins"] = int(Game.stats["spins"]) + 1
	_result = [_roll(), _roll(), _roll()]
	if randf() < Game.slot_luck():
		_result[2] = _result[0]
	_msg.text = "Bet $%s . . ." % Game.fmt(bet)
	_msg.add_theme_color_override("font_color", ThemeBuilder.DIM)
	_lever = 1.0
	Sfx.play("lever")
	for r in 3:
		_stopped[r] = false
		_speeds[r] = 14.0 + r * 1.5
	_refresh_bets()
	for r in 3:
		get_tree().create_timer(0.8 + r * 0.45).timeout.connect(_stop_reel.bind(r))


func _stop_reel(r: int) -> void:
	var off: float = _offsets[r]
	var target := floorf(off) + 3.0
	var idx := int(target) % STRIP_LEN
	_strips[r][idx] = _result[r]
	_speeds[r] = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v): _offsets[r] = v, off, target, 0.35)
	tw.tween_callback(func():
		_stopped[r] = true
		Sfx.play("clunk", -2.0)
		if r == 2:
			_finish())


func _finish() -> void:
	spinning = false
	var a: String = _result[0]
	var b: String = _result[1]
	var c: String = _result[2]
	var mult := 0.0
	var kind := ""
	if a == b and b == c:
		mult = TRIPLE[a]
		kind = a
	else:
		for s in [a, b, c]:
			if [a, b, c].count(s) == 2:
				mult = PAIR[s]
		if mult == 0.0 and "star" in [a, b, c] and not (a == b or b == c or a == c):
			mult = 1.0
	if kind == "cow":
		_msg.text = "THREE COWS! The cows win. They're coming to the field."
		_msg.add_theme_color_override("font_color", ThemeBuilder.BAD)
		Sfx.play("moo")
		Game.say(Quips.pick(Quips.SLOT_COW), 4.0)
		prize.emit("cow")
	elif mult > 0.0:
		var win := floorf(_last_bet * mult)
		_pending_win = win
		var big := mult >= 10.0
		_msg.text = ("JACKPOT!!  " if kind == "star" else "") + "WIN $%s  (x%s)" % [Game.fmt(win), str(mult)]
		_msg.add_theme_color_override("font_color", ThemeBuilder.APPROVAL)
		_flash = 1.0
		_win_glow = 2.5 if big else 1.2
		Sfx.play("jackpot" if big else "win")
		if kind == "star":
			Game.stats["jackpots"] = int(Game.stats["jackpots"]) + 1
			Game.say(Quips.pick(Quips.SLOT_JACKPOT), 4.0)
		elif big or randf() < 0.3:
			Game.say(Quips.pick(Quips.SLOT_WIN), 3.5)
		if kind != "":
			prize.emit(kind)
		if mult >= 1.0 and win > 0.0:
			_show_double(true)
	else:
		_msg.text = "Nothing. The Mothership thanks you for your donation."
		_msg.add_theme_color_override("font_color", ThemeBuilder.DIM)
		Sfx.play("lose", -4.0)
		if randf() < 0.4:
			Game.say(Quips.pick(Quips.SLOT_LOSE), 3.5)
	_refresh_bets()


func _show_double(on: bool) -> void:
	_double_btn.visible = on
	_collect_btn.visible = on
	_spin_btn.visible = not on


func _collect() -> void:
	if _pending_win <= 0.0:
		return
	Game.earn(_pending_win)
	Sfx.play("cash")
	_msg.text = "Collected $%s" % Game.fmt(_pending_win)
	_pending_win = 0.0
	_show_double(false)
	_refresh_bets()


func _double() -> void:
	if _pending_win <= 0.0:
		return
	var p := 0.45 + Game.slot_luck() * 0.25
	if randf() < p:
		_pending_win *= 2.0
		_msg.text = "DOUBLED! $%s . Again?" % Game.fmt(_pending_win)
		_msg.add_theme_color_override("font_color", ThemeBuilder.APPROVAL)
		_flash = 0.7
		Sfx.play("win")
	else:
		_msg.text = "Gone. The Mothership giveth, the Mothership taketh."
		_msg.add_theme_color_override("font_color", ThemeBuilder.BAD)
		_pending_win = 0.0
		Sfx.play("lose", -4.0)
		_show_double(false)
	_refresh_bets()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for r in 3:
		if not _stopped[r] and _speeds[r] > 0.0:
			var before := floorf(_offsets[r])
			_offsets[r] = float(_offsets[r]) + _speeds[r] * delta
			if floorf(_offsets[r]) != before and r == 0:
				Sfx.play("reel", -10.0, 0.1, 20)
	_lever = maxf(0.0, _lever - delta * 2.0)
	_flash = maxf(0.0, _flash - delta * 1.5)
	_win_glow = maxf(0.0, _win_glow - delta)
	_panel.queue_redraw()
	_reels.queue_redraw()


func _draw_panel() -> void:
	var p := _panel
	var r := Rect2(Vector2.ZERO, PANEL)
	# Body.
	p.draw_rect(r.grow(4), Color(0.02, 0.02, 0.04))
	p.draw_rect(r, Color(0.32, 0.08, 0.11))
	p.draw_rect(Rect2(8, 8, PANEL.x - 16, PANEL.y - 16), Color(0.45, 0.12, 0.15))
	p.draw_rect(Rect2(16, 16, PANEL.x - 32, PANEL.y - 32), Color(0.10, 0.07, 0.10))
	# Bulbs around the edge.
	var n := 0
	var x := 20.0
	while x < PANEL.x - 20:
		for y in [4.0, PANEL.y - 12.0]:
			_bulb(p, Vector2(x, y), n)
			n += 1
		x += 24.0
	var y2 := 28.0
	while y2 < PANEL.y - 20:
		for xx in [4.0, PANEL.x - 12.0]:
			_bulb(p, Vector2(xx, y2), n)
			n += 1
		y2 += 24.0
	# Title.
	var title := "MOTHERSHIP SLOT"
	var size := 30
	var w := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var tx := (PANEL.x - w) * 0.5
	for i in title.length():
		var ch := title[i]
		var cw := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var bob := roundf(sin(_time * 4.0 + i * 0.5) * 2.0)
		p.draw_string_outline(_font, Vector2(tx, 72 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(0.02, 0.02, 0.04))
		p.draw_string(_font, Vector2(tx, 72 + bob), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.85, 0.35).lerp(Color(0.5, 1, 0.85), 0.5 + 0.5 * sin(_time * 3.0 + i * 0.4)))
		tx += cw
	# Reel window frame.
	var win := Rect2(_reels.position, _reels.size).grow(8)
	p.draw_rect(win, Color(0.8, 0.82, 0.88))
	p.draw_rect(win.grow(-4), Color(0.02, 0.02, 0.04))
	if _win_glow > 0.0:
		p.draw_rect(win.grow(4), Color(1, 0.9, 0.4, 0.25 * minf(_win_glow, 1.0) * (0.5 + 0.5 * sin(_time * 25.0))))
	# Lever.
	var base := Vector2(PANEL.x - 40, 200)
	var top := base + Vector2(0, -80).rotated(_lever * 2.4)
	p.draw_line(base, top, Color(0.75, 0.77, 0.82), 6)
	p.draw_circle(top, 11, Color(0.02, 0.02, 0.04))
	p.draw_circle(top, 9, Color(0.9, 0.2, 0.2))
	p.draw_rect(Rect2(base - Vector2(10, 6), Vector2(20, 22)), Color(0.4, 0.4, 0.46))
	# Paytable.
	var lines := [
		["star", "x50 JACKPOT"], ["ufo", "x20 + giant circle"], ["circle", "x10 + giant circle"],
		["alien", "x6 + free alien"], ["wheat", "x4 + golden wheat"], ["cow", "the cows win"],
	]
	var px := 40.0
	var py := 448.0
	for i in lines.size():
		var col := i % 2
		var row := i / 2
		var pos := Vector2(px + col * 250.0, py + row * 26.0)
		for k in 3:
			p.draw_texture_rect(_icons[lines[i][0]], Rect2(pos + Vector2(k * 18, 0), Vector2(16, 16)), false)
		p.draw_string(_font, pos + Vector2(62, 13), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ThemeBuilder.TEXT)
	p.draw_string(_font, Vector2(40, PANEL.y - 22), "Any pair pays x1.2 to x3.  One star = money back.", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ThemeBuilder.DIM)
	if _flash > 0.0:
		p.draw_rect(r, Color(1, 0.95, 0.7, _flash * 0.25))


func _bulb(p: Control, at: Vector2, n: int) -> void:
	var on := (n + int(_time * 8.0)) % 3 == 0
	if _win_glow > 0.0:
		on = int(_time * 16.0) % 2 == n % 2
	p.draw_rect(Rect2(at, Vector2(8, 8)), Color(1, 0.92, 0.5) if on else Color(0.45, 0.3, 0.15))


func _draw_reels() -> void:
	var c := _reels
	var reel_w := 400.0 / 3.0
	for r in 3:
		var x0 := r * reel_w
		c.draw_rect(Rect2(x0 + 4, 0, reel_w - 8, 150), Color(0.93, 0.9, 0.84))
		var off: float = _offsets[r]
		var base := floorf(off)
		var frac := off - base
		for k in range(-2, 3):
			var idx := int(posmod(int(base) + k, STRIP_LEN))
			var sym: String = _strips[r][idx]
			var y := 75.0 + (k - frac) * SYM_PX * 1.1 - SYM_PX * 0.5
			var blur: bool = not _stopped[r] and _speeds[r] > 0.0
			var rect := Rect2(x0 + (reel_w - SYM_PX) * 0.5, y, SYM_PX, SYM_PX)
			c.draw_texture_rect(_icons[sym], rect, false, Color(1, 1, 1, 0.55 if blur else 1.0))
			if blur:
				c.draw_texture_rect(_icons[sym], Rect2(rect.position + Vector2(0, -14), rect.size), false, Color(1, 1, 1, 0.25))
		# Shading top and bottom.
		for s in 6:
			var a := 0.5 - s * 0.08
			c.draw_rect(Rect2(x0 + 4, s * 4, reel_w - 8, 4), Color(0, 0, 0, a))
			c.draw_rect(Rect2(x0 + 4, 146 - s * 4, reel_w - 8, 4), Color(0, 0, 0, a))
	# Pay line.
	c.draw_rect(Rect2(0, 74, 400, 2), Color(1, 0.3, 0.3, 0.6))
