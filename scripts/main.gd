extends Node2D
## Builds the game and glues it together: the table, the field, the crew,
## effects, HUD, menus, CRT and cursor. Handles your hand, crop circle
## payouts, the slot machine's prizes, saving, and the harvest (prestige).

const FIELD_POS := Vector2(180, 96)
const AUTOSAVE := 15.0

var table: Table
var field: Field
var aliens: Aliens
var fx: Effects
var hud: Hud
var menu: Menu
var camera: Camera2D

var playing := false
var harvesting := false

var _drawing := false
var _last_cell := Vector2.ZERO
var _rustle_t := 0.0
var _shake := 0.0
var _save_t := AUTOSAVE
var _tourist_t := 0.0
var _sparkle_t := 0.0
var _harvesters: Array = []
var _harvest_x := 0.0


func _ready() -> void:
	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()

	table = Table.new()
	add_child(table)
	field = Field.new()
	field.position = FIELD_POS
	add_child(field)
	table.field_rect = Rect2(FIELD_POS, field.size_px())
	aliens = Aliens.new()
	aliens.field = field
	add_child(aliens)
	fx = Effects.new()
	add_child(fx)
	aliens.fx = fx
	field.circle_locked.connect(_on_circle)

	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.harvest_confirmed.connect(_start_harvest)
	hud.menu_requested.connect(_pause)
	hud.slot_requested.connect(_open_slot)
	hud.slot.prize.connect(_on_prize)
	menu = Menu.new()
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu)
	menu.play.connect(_on_play)
	menu.resumed.connect(_on_resume)
	menu.to_title.connect(_to_title)
	var crt := CrtOverlay.new()
	add_child(crt)
	var cur := GameCursor.new()
	cur.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cur)

	Game.changed.connect(aliens.sync)
	get_tree().set_auto_accept_quit(false)
	_attract_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if playing:
			Game.save_game()
		Game.save_settings()
		get_tree().quit()


# ---------------------------------------------------------------- flow

func _attract_mode() -> void:
	playing = false
	hud.visible = false
	aliens.demo = true
	aliens.clear_all()
	aliens.sync()
	menu.show_title()


func _on_play(new_game: bool) -> void:
	if new_game:
		Game.wipe()
	else:
		Game.load_game()
	menu.hide_menu()
	field.reset_field()
	aliens.demo = false
	aliens.clear_all()
	aliens.sync()
	hud.visible = true
	hud.refresh()
	playing = true
	Sfx.play("lock")
	if not Game.intro_done:
		Game.intro_done = true
		for i in Quips.INTRO.size():
			get_tree().create_timer(0.6 + i * 6.5).timeout.connect(Game.say.bind(Quips.INTRO[i], 4.0))
	else:
		Game.say("Welcome back. The wheat missed you. %s awaits." % Game.season_name(), 4.0)
	Game.save_game()


func _pause() -> void:
	if not playing or harvesting:
		return
	_drawing = false
	get_tree().paused = true
	menu.show_pause()


func _on_resume() -> void:
	get_tree().paused = false


func _to_title() -> void:
	Game.save_game()
	get_tree().paused = false
	hud.slot.visible = false
	_attract_mode()


func _open_slot() -> void:
	if not playing or harvesting:
		return
	if hud.slot.visible:
		hud.slot.close_slot()
	else:
		_drawing = false
		hud.slot.open_slot()
		table.flash_slot()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not playing or harvesting:
		return
	var k := event as InputEventKey
	if k and k.pressed and not k.echo:
		if k.keycode == KEY_ESCAPE and not hud.slot.visible and not hud.is_popup_open():
			_pause()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_S:
			_open_slot()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			var p := get_global_mouse_position()
			if hud.mouse_over_ui(mb.position):
				return
			if table.slot_rect().has_point(p):
				_open_slot()
				return
			var c := field.world_to_cell(p)
			if field.in_field(c):
				_drawing = true
				_last_cell = c
				_stamp_hand(c, c)
		else:
			_drawing = false
	var mm := event as InputEventMouseMotion
	if mm and _drawing:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_drawing = false
			return
		var c := field.world_to_cell(get_global_mouse_position())
		_stamp_hand(_last_cell, c)
		_last_cell = c


func _stamp_hand(a: Vector2, b: Vector2) -> void:
	var fell := field.stamp_line(a, b, Game.hand_radius(), Field.OWNER_PLAYER)
	if fell > 0:
		var w := field.cell_to_world(b)
		fx.chaff(w, mini(1 + fell / 3, 5), (b - a).normalized())
		if _rustle_t <= 0.0:
			_rustle_t = 0.07
			Sfx.play("rustle", -8.0, 0.2, 40)


# ---------------------------------------------------------------- payouts

func _on_circle(c: Dictionary) -> void:
	var center_w := field.cell_to_world(c["center"])
	var radius_px: float = float(c["radius"]) * Game.CELL
	var maker: int = c["maker"]
	var demo := not playing
	var kind: String = c["kind"]
	var special := kind in ["Perfect Circle", "Bullseye"]

	# Effects first: swirl flash, ring, motes.
	fx.flash(center_w, radius_px * 1.1, Color(0.6, 1.0, 0.9), 0.35)
	fx.ring(center_w, radius_px * 1.8, Color(0.7, 1.0, 0.9, 0.9), 0.6)
	fx.motes(center_w, radius_px, clampi(int(c["area"]) / 8, 6, 60))
	if demo:
		Sfx.play("lock", -10.0)
		return

	var cows := aliens.abduct_in(c)
	var glow := aliens.glow_mult(c["center"])
	c["aura"] = glow
	var shape := 1.0 + (float(c["mult"]) - 1.0) * Game.shape_bonus_scale()
	var combo := Game.bump_combo()
	var value := float(c["area"]) * Game.cell_value() * shape * glow * aliens.maker_bonus(maker) * combo
	value *= pow(2.0, cows)
	var golden: int = c["golden"]
	if golden > 0:
		value += golden * Game.cell_value() * 40.0 * glow
	Game.earn(value)
	Game.stats["circles"] = int(Game.stats["circles"]) + 1
	if kind == "Perfect Circle":
		Game.stats["perfect"] = int(Game.stats["perfect"]) + 1
	Game.stats["cows"] = int(Game.stats["cows"]) + cows
	Game.stats["golden"] = int(Game.stats["golden"]) + golden
	Game.stats["best"] = maxf(float(Game.stats["best"]), value)

	var big := special or int(c["area"]) > 250 or cows > 0
	Sfx.play("lock_big" if big else "lock", -2.0 if maker == Field.OWNER_PLAYER else -9.0, 0.06, 60)
	Sfx.play("coin", -6.0, 0.15, 50)
	fx.coins(center_w, clampi(int(log(value + 1.0) * 2.0), 3, 30))
	var size := 14 if maker == Field.OWNER_PLAYER else 11
	if big:
		size = 18
	fx.pop(center_w + Vector2(0, -6), "+$" + Game.fmt(value), ThemeBuilder.MONEY, size, 1.3)
	if maker == Field.OWNER_PLAYER or special or kind == "Alien Glyph":
		var col := Color(0.6, 1.0, 0.9) if special else ThemeBuilder.TEXT
		fx.pop(center_w + Vector2(0, -26), kind.to_upper() + ("  x%.1f" % shape if shape > 1.0 else ""), col, 10 if not special else 13, 1.4)
	if Game.combo > 0 and maker == Field.OWNER_PLAYER:
		Sfx.play("combo", -6.0, 0.0, 40)
	if big:
		shake(4.0 if special else 2.5)
		hud.flash(0.08, Color(0.7, 1.0, 0.9))
	if cows > 0:
		Sfx.play("beam", -2.0)
		Sfx.play("moo", -4.0, 0.2, 200)
		fx.pop(center_w + Vector2(0, -44), "COW ABDUCTED!  x%d" % int(pow(2, cows)), Color(1, 0.7, 0.85), 13, 1.6)
		if randf() < 0.6:
			Game.say(Quips.pick(Quips.COW), 3.5)
	if golden > 0:
		Sfx.play("find", -4.0)
		fx.pop(center_w + Vector2(0, -62), "GOLDEN WHEAT x%d" % golden, Color(1, 0.9, 0.45), 12, 1.5)
		if randf() < 0.3:
			Game.say(Quips.pick(Quips.GOLDEN), 3.0)
	if maker == Field.OWNER_PLAYER:
		if kind == "Perfect Circle" and randf() < 0.35:
			Game.say(Quips.pick(Quips.PERFECT), 3.5)
		elif kind == "Bullseye" and randf() < 0.6:
			Game.say(Quips.pick(Quips.BULLSEYE), 3.5)
		elif kind == "Blob" and randf() < 0.15:
			Game.say(Quips.pick(Quips.BLOB), 3.0)
	if Game.combo == 4:
		Game.say(Quips.pick(Quips.COMBO), 2.5)


func _on_prize(kind: String) -> void:
	match kind:
		"ufo", "circle":
			aliens.giant_circle()
			hud.toast("A saucer is coming to draw a giant circle!", Color(0.6, 1.0, 0.9))
		"alien":
			var best := "greeblet"
			for d in Defs.ALIENS:
				if Game.alien_unlocked(d["id"]):
					best = d["id"]
			Game.aliens[best] = Game.count(best) + 1
			Game.changed.emit()
			hud.toast("Free %s!" % Defs.find(Defs.ALIENS, best)["name"], ThemeBuilder.APPROVAL)
		"wheat":
			field.spawn_golden(12)
			hud.toast("Golden wheat shower!", Color(1, 0.9, 0.45))
		"cow":
			aliens.add_cows(3)
		"star":
			shake(6.0)
			hud.flash(0.3, Color(1, 0.9, 0.5))


func shake(amount: float) -> void:
	if Game.screen_shake:
		_shake = maxf(_shake, amount)


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_rustle_t -= delta
	# Screen shake.
	if _shake > 0.0:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * roundf(_shake)
		_shake = maxf(0.0, _shake - delta * 18.0)
	else:
		camera.offset = Vector2.ZERO

	var mouse := get_viewport().get_mouse_position()
	var world := get_global_mouse_position()
	var over_ui := not playing or hud.mouse_over_ui(mouse) or harvesting
	var cell := field.world_to_cell(world)
	field.show_hover = not over_ui and field.in_field(cell)
	field.hover_cell = cell
	field.hover_radius = Game.hand_radius()
	table.slot_hover = not over_ui and table.slot_rect().has_point(world)

	if playing and not harvesting:
		_save_t -= delta
		if _save_t <= 0.0:
			_save_t = AUTOSAVE
			Game.save_game()
		_tourists(delta)
	_sparkle_t -= delta
	if _sparkle_t <= 0.0:
		_sparkle_t = 0.15
		var gp := field.golden_positions()
		if not gp.is_empty():
			fx.sparkle(gp[randi() % gp.size()] + Vector2(randf_range(-4, 4), randf_range(-4, 4)))
	if harvesting:
		_update_harvest(delta)


func _tourists(delta: float) -> void:
	var rate := Game.tourist_rate()
	if rate <= 0.0:
		return
	_tourist_t -= delta
	for s in field.circles:
		var c: Dictionary = field.circles[s]
		c["tourist_acc"] = float(c["tourist_acc"]) + float(c["area"]) * rate * float(c.get("aura", 1.0)) * delta
	if _tourist_t <= 0.0:
		_tourist_t = 1.5
		var shown := 0
		for s in field.circles:
			var c: Dictionary = field.circles[s]
			var amt: float = c["tourist_acc"]
			if amt <= 0.0:
				continue
			Game.earn(amt)
			c["tourist_acc"] = 0.0
			if shown < 4 and amt >= 0.5:
				shown += 1
				fx.pop(field.cell_to_world(c["center"]) + Vector2(0, -10), "+$" + Game.fmt(amt), Color(0.56, 0.89, 0.53, 0.8), 9, 0.9)


# ---------------------------------------------------------------- harvest

func _start_harvest() -> void:
	if harvesting or not Game.goal_reached():
		return
	harvesting = true
	_drawing = false
	field.paused = true
	Game.say(Quips.pick(Quips.HARVEST), 4.0)
	Sfx.play("harvest", 0.0, 0.0, 0)
	table.farmer_visible = true
	table.farmer_x = 120
	_harvest_x = -30.0
	var tex: Texture2D = load("res://assets/sprites/harvester.png")
	for i in 3:
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.scale = Vector2(Game.CELL, Game.CELL)
		s.flip_h = true
		s.position = FIELD_POS + Vector2(-tex.get_width() * Game.CELL, (i + 0.5) * field.size_px().y / 3.0 - tex.get_height() * Game.CELL * 0.5)
		add_child(s)
		_harvesters.append(s)


func _update_harvest(delta: float) -> void:
	_harvest_x += delta * 60.0
	var x_px := FIELD_POS.x + _harvest_x * Game.CELL
	for s in _harvesters:
		(s as Sprite2D).position.x = x_px - 6 * Game.CELL
		(s as Sprite2D).position.y += sin(Time.get_ticks_msec() * 0.03) * 0.3
		if randf() < 0.6:
			fx.chaff((s as Sprite2D).position + Vector2(0, randf_range(10, 40)), 2, Vector2(-1, 0))
	field.cut_to(int(_harvest_x))
	if randf() < 0.1:
		shake(1.5)
	if _harvest_x > Field.W + 40:
		_finish_harvest()


func _finish_harvest() -> void:
	for s in _harvesters:
		s.queue_free()
	_harvesters.clear()
	table.farmer_visible = false
	var gained := Game.signal_gain()
	var was_won := Game.won
	Game.harvest()
	field.reset_field()
	field.paused = false
	aliens.clear_all()
	aliens.sync()
	harvesting = false
	Game.save_game()
	Sfx.play("clear")
	hud.flash(0.35, Color(0.7, 1.0, 0.9))
	if Game.won and not was_won:
		Game.say(Quips.pick(Quips.WIN), 6.0)
		hud.show_popup("CONTACT!",
			"After seven seasons of circles, the Mothership finally answered.\nIts message: \"MORE CIRCLES PLEASE.\"\n\nYou win! Keep playing for endless seasons and bigger numbers.",
			[["Keep circling", func(): pass]])
	else:
		hud.show_popup("Season %d: %s" % [Game.season + 1, Game.season_name()],
			"+%d Signal. Spend it in the Signal tab.\nThis season's goal: $%s" % [gained, Game.fmt(Game.season_goal())],
			[["Let's go", func(): Game.say(Quips.pick(Quips.SEASON), 4.0)]])
