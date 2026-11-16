class_name Hud
extends CanvasLayer
## All in-game UI, built in code (colours live in theme_builder.gd).
## Top bar: money, $/sec, season goal, combo, slot + menu buttons.
## Right panel (collapsible, Tab): Crew / Upgrades / Signal.
## Bottom-left: the Overlord. Popups and the slot machine sit on top.

signal harvest_confirmed
signal menu_requested
signal slot_requested

const TOP_H := 50.0
const PANEL_W := 316.0
const HANDLE_W := 22.0
const SCREEN := Vector2(1280, 720)

var panel_open := true
var overlord: Overlord
var slot: SlotMachine

var _root: Control
var _money: Label
var _shown_money := 0.0
var _rate: Label
var _season_label: Label
var _progress: ProgressBar
var _combo: Label
var _combo_bar: ProgressBar
var _panel: PanelContainer
var _handle: Button
var _rows := {}
var _signal_big: Label
var _harvest_btn: Button
var _stats: Label
var _toasts: VBoxContainer
var _flash: ColorRect
var _popup_bg: ColorRect
var _popup_title: Label
var _popup_body: Label
var _popup_buttons: HBoxContainer
var _refresh_timer := 0.0
var _last_combo := 0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.size = SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = ThemeBuilder.build()
	add_child(_root)
	_build_vignette()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = SCREEN
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	overlord = Overlord.new()
	_root.add_child(overlord)
	_build_top_bar()
	_build_side_panel()
	_toasts = VBoxContainer.new()
	_toasts.custom_minimum_size = Vector2(440, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_build_popup()
	slot = SlotMachine.new()
	_root.add_child(slot)
	_shown_money = Game.money
	_layout(false)
	Game.changed.connect(refresh)
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_TAB and visible:
		toggle_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		refresh()
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.2)
	var target := Game.money
	if absf(target - _shown_money) < 0.01 or absf(target - _shown_money) / maxf(target, 1.0) < 0.001:
		_shown_money = target
	else:
		if target > _shown_money and _money.scale.x < 1.05:
			_money.scale = Vector2(1.15, 1.15)
		_shown_money = lerpf(_shown_money, target, minf(1.0, delta * 9.0))
	_money.text = "$" + Game.fmt(_shown_money)
	_money.scale = _money.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	# Combo meter.
	if Game.combo > 0 and Game.combo_left > 0.0:
		_combo.visible = true
		_combo_bar.visible = true
		_combo.text = "COMBO x%d" % (Game.combo + 1)
		_combo_bar.value = Game.combo_left / Game.combo_window() * 100.0
		if Game.combo != _last_combo:
			_combo.scale = Vector2(1.35, 1.35)
		_combo.scale = _combo.scale.lerp(Vector2.ONE, minf(1.0, delta * 8.0))
		_combo.modulate = Color(1, 1, 1).lerp(Color(0.5, 1.0, 0.85), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
	else:
		_combo.visible = false
		_combo_bar.visible = false
	_last_combo = Game.combo


func play_area() -> Rect2:
	var right := SCREEN.x - (PANEL_W if panel_open else 0.0)
	return Rect2(0, TOP_H, right, SCREEN.y - TOP_H)


func flash(strength: float, color := Color(1, 0.97, 0.9)) -> void:
	_flash.color = Color(color, clampf(strength, 0.0, 1.0))


func toast(text: String, color := ThemeBuilder.TEXT) -> void:
	var l := _label(text, 16, color, ThemeBuilder.title_font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	if _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()


func mouse_over_ui(p: Vector2) -> bool:
	if is_popup_open() or slot.visible or p.y < TOP_H:
		return true
	if panel_open and p.x >= SCREEN.x - PANEL_W - HANDLE_W:
		return true
	if not panel_open and p.x >= SCREEN.x - HANDLE_W and p.y < TOP_H + 90:
		return true
	return false


func toggle_panel() -> void:
	panel_open = not panel_open
	Sfx.play("tick", -6.0)
	_layout(true)


func _layout(animate: bool) -> void:
	var panel_x := SCREEN.x - PANEL_W if panel_open else SCREEN.x + 4.0
	if animate:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "position:x", panel_x, 0.22)
		tw.tween_property(_handle, "position:x", panel_x - HANDLE_W, 0.22)
	else:
		_panel.position.x = panel_x
		_handle.position.x = panel_x - HANDLE_W
	_handle.text = ">" if panel_open else "<"
	_handle.tooltip_text = ("Hide" if panel_open else "Show") + " the shop (Tab)"
	var area := play_area()
	_toasts.position = Vector2(area.get_center().x - 220, TOP_H + 10)


# ---------------------------------------------------------------- builders

func _label(text: String, size := 16, color := ThemeBuilder.TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, size := 14, color := ThemeBuilder.DIM) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.55))
	g.add_point(0.6, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var vig := TextureRect.new()
	vig.texture = tex
	vig.size = SCREEN
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vig)


func _icon_button(icon: String, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 38)
	b.tooltip_text = tip
	b.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/%s.png" % icon)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.offset_left = 6
	t.offset_top = 5
	t.offset_right = -6
	t.offset_bottom = -5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	return b


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.size = Vector2(SCREEN.x, TOP_H)
	var sb := ThemeBuilder.box(Color(0.045, 0.04, 0.055, 0.94), ThemeBuilder.BORDER, 0, 10.0)
	sb.border_width_bottom = 1
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	_root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	bar.add_child(hb)

	_money = _label("$0", 26, ThemeBuilder.MONEY, ThemeBuilder.title_font)
	_money.custom_minimum_size = Vector2(190, 0)
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.pivot_offset = Vector2(10, 20)
	hb.add_child(_money)
	_rate = _label("", 13, ThemeBuilder.DIM, ThemeBuilder.title_font)
	_rate.custom_minimum_size = Vector2(110, 0)
	_rate.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_rate)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.tooltip_text = "Earn this much this season, then harvest (Signal tab) for Signal."
	hb.add_child(vb)
	_season_label = _label("", 14, ThemeBuilder.TEXT)
	vb.add_child(_season_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_progress)

	var cb := VBoxContainer.new()
	cb.custom_minimum_size = Vector2(130, 0)
	cb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(cb)
	_combo = _label("", 16, ThemeBuilder.APPROVAL, ThemeBuilder.title_font)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo.pivot_offset = Vector2(65, 10)
	cb.add_child(_combo)
	_combo_bar = ProgressBar.new()
	_combo_bar.custom_minimum_size = Vector2(0, 4)
	_combo_bar.show_percentage = false
	cb.add_child(_combo_bar)

	var slot_btn := _icon_button("sym_star", "Mothership Slot (S)")
	slot_btn.pressed.connect(func(): slot_requested.emit())
	hb.add_child(slot_btn)
	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.add_theme_font_override("font", ThemeBuilder.title_font)
	menu_btn.add_theme_font_size_override("font_size", 12)
	menu_btn.custom_minimum_size = Vector2(70, 38)
	menu_btn.tooltip_text = "Pause, options, save (Esc)"
	menu_btn.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
	menu_btn.pressed.connect(func(): menu_requested.emit())
	hb.add_child(menu_btn)


func _build_side_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(SCREEN.x - PANEL_W, TOP_H)
	_panel.size = Vector2(PANEL_W, SCREEN.y - TOP_H)
	var sb := ThemeBuilder.box(ThemeBuilder.BG, ThemeBuilder.BORDER, 0, 6.0)
	sb.border_width_left = 1
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var tabs := TabContainer.new()
	tabs.tab_changed.connect(func(_i): Sfx.play("tick", -10.0))
	_panel.add_child(tabs)

	var crew := _scroll_tab(tabs, "Crew")
	crew.add_child(_wrap("Aliens make crop circles for you. Hover for details."))
	for def in Defs.ALIENS:
		_rows[def["id"]] = _row(crew, def, "alien")

	var ups := _scroll_tab(tabs, "Upgrades")
	for def in Defs.UPGRADES:
		_rows[def["id"]] = _row(ups, def, "upgrade")

	var sig := _scroll_tab(tabs, "Signal")
	_signal_big = _label("", 15, ThemeBuilder.APPROVAL, ThemeBuilder.title_font)
	sig.add_child(_signal_big)
	sig.add_child(_wrap("Reach the season goal, then let the farmer harvest. You lose your money, crew and upgrades, but earn Signal. Signal perks last forever. Harvest all 7 seasons to make contact."))
	_harvest_btn = Button.new()
	_harvest_btn.custom_minimum_size = Vector2(0, 44)
	_harvest_btn.add_theme_font_override("font", ThemeBuilder.title_font)
	_harvest_btn.add_theme_font_size_override("font_size", 13)
	_harvest_btn.pressed.connect(_ask_harvest)
	sig.add_child(_harvest_btn)
	sig.add_child(HSeparator.new())
	for def in Defs.SIGNAL:
		_rows["sig_" + def["id"]] = _row(sig, def, "signal")
	sig.add_child(HSeparator.new())
	_stats = _wrap("")
	sig.add_child(_stats)

	_handle = Button.new()
	_handle.size = Vector2(HANDLE_W, 72)
	_handle.position = Vector2(SCREEN.x - PANEL_W - HANDLE_W, TOP_H + 10)
	_handle.add_theme_font_override("font", ThemeBuilder.title_font)
	_handle.pressed.connect(toggle_panel)
	_root.add_child(_handle)


func _scroll_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	sc.add_child(vb)
	return vb


## One shop row: [icon] Name / level underneath ........ price.
## The whole row is the buy button; hovering shows the description.
func _row(parent: VBoxContainer, def: Dictionary, kind: String) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 56)
	btn.tooltip_text = "%s\n%s" % [def["name"], def["desc"]]
	btn.mouse_entered.connect(func(): Sfx.play("hover", -18.0, 0.1, 40))
	parent.add_child(btn)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.05, 0.045, 0.06), ThemeBuilder.BORDER, 1, 3.0))
	frame.custom_minimum_size = Vector2(46, 46)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(frame)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.png" % def["icon"])
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(38, 38)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var name_l := _label(def["name"], 16, ThemeBuilder.TEXT)
	name_l.clip_text = true
	vb.add_child(name_l)
	var lvl := _label("", 11, ThemeBuilder.ACCENT, ThemeBuilder.title_font)
	vb.add_child(lvl)
	var price := _label("", 12, ThemeBuilder.MONEY, ThemeBuilder.title_font)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(price)

	var id: String = def["id"]
	btn.pressed.connect(func():
		var ok := false
		match kind:
			"alien":
				ok = Game.buy_alien(id)
				if ok and randf() < 0.25:
					Game.say(Quips.pick(Quips.BUY), 3.0)
			"upgrade":
				ok = Game.buy_upgrade(id)
			"signal":
				ok = Game.buy_signal(id)
		if ok:
			Sfx.play("buy")
			btn.modulate = Color(1.6, 1.5, 1.1)
			btn.create_tween().tween_property(btn, "modulate", Color.WHITE, 0.3)
			icon.pivot_offset = Vector2(19, 19)
			icon.scale = Vector2(1.35, 1.35)
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		else:
			Sfx.play("deny", -8.0))
	return {"button": btn, "name": name_l, "level": lvl, "price": price, "def": def, "kind": kind, "icon": icon}


# ----------------------------------------------------------------- popup

func _build_popup() -> void:
	_popup_bg = ColorRect.new()
	_popup_bg.color = Color(0, 0, 0.02, 0.72)
	_popup_bg.size = SCREEN
	_popup_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_popup_bg)
	var center := CenterContainer.new()
	center.size = SCREEN
	_popup_bg.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(ThemeBuilder.BG_SOLID, ThemeBuilder.ACCENT, 2, 26.0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	_popup_title = _label("", 28, ThemeBuilder.ACCENT, ThemeBuilder.title_font)
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_popup_title)
	_popup_body = _label("", 18, ThemeBuilder.TEXT)
	_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_body.custom_minimum_size = Vector2(520, 0)
	_popup_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_popup_body)
	_popup_buttons = HBoxContainer.new()
	_popup_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_buttons.add_theme_constant_override("separation", 16)
	vb.add_child(_popup_buttons)
	_popup_bg.visible = false


func is_popup_open() -> bool:
	return _popup_bg.visible


## buttons: Array of [text, Callable]
func show_popup(title: String, body: String, buttons: Array) -> void:
	_popup_title.text = title
	_popup_body.text = body
	for c in _popup_buttons.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = "  %s  " % b[0]
		btn.custom_minimum_size = Vector2(160, 44)
		btn.mouse_entered.connect(Sfx.play.bind("hover", -16.0))
		var cb: Callable = b[1]
		btn.pressed.connect(func():
			Sfx.play("tick")
			_popup_bg.visible = false
			cb.call())
		_popup_buttons.add_child(btn)
	_popup_bg.visible = true
	_popup_bg.modulate.a = 0.0
	create_tween().tween_property(_popup_bg, "modulate:a", 1.0, 0.2)
	Sfx.play("pop")


func _ask_harvest() -> void:
	if not Game.goal_reached():
		Sfx.play("deny")
		return
	var last := Game.season + 1 >= Game.SEASON_COUNT and not Game.won
	show_popup("Harvest?" if not last else "Final harvest?",
		"The farmer cuts the field. You keep %d Signal (+%d now) and lose this season's money, crew and upgrades.%s" % [
			Game.signal_pts + Game.signal_gain(), Game.signal_gain(),
			"\n\nThis is the last field. The Mothership is listening..." if last else ""],
		[["Harvest!", func(): harvest_confirmed.emit()], ["Not yet", func(): pass]])


# --------------------------------------------------------------- refresh

func refresh() -> void:
	if _money == null:
		return
	_rate.text = "$%s/s" % Game.fmt(Game.per_second())
	var goal := Game.season_goal()
	var frac := clampf(Game.season_earned / goal, 0.0, 1.0)
	_season_label.text = "Season %d/%d  %s     $%s / $%s" % [mini(Game.season + 1, 99), Game.SEASON_COUNT, Game.season_name(), Game.fmt(Game.season_earned), Game.fmt(goal)]
	_progress.value = frac * 100.0
	_progress.modulate = Color(0.6, 1.4, 1.2) if frac >= 1.0 else Color.WHITE

	var prev_owned := true
	for id in _rows:
		var row: Dictionary = _rows[id]
		var def: Dictionary = row["def"]
		var btn: Button = row["button"]
		var lvl_l: Label = row["level"]
		var price_l: Label = row["price"]
		var name_l: Label = row["name"]
		var real_id: String = def["id"]
		var price := 0.0
		var can := false
		var maxed := false
		match row["kind"]:
			"alien":
				var unlocked := Game.alien_unlocked(real_id)
				btn.visible = unlocked or prev_owned
				prev_owned = unlocked
				name_l.text = def["name"] if unlocked else "???"
				(row["icon"] as TextureRect).modulate = Color.WHITE if unlocked else Color(0, 0, 0, 0.8)
				lvl_l.text = "OWNED %d" % Game.count(real_id)
				price = Game.alien_cost(real_id)
				can = unlocked and Game.money >= price
				if not unlocked:
					btn.tooltip_text = "Buy a %s first." % _prev_alien_name(real_id)
				else:
					btn.tooltip_text = "%s\n%s" % [def["name"], def["desc"]]
			"upgrade":
				var lvl := Game.lvl(real_id)
				lvl_l.text = "LV %d" % lvl + ("/%d" % int(def["max"]) if int(def["max"]) > 0 else "")
				maxed = Game.is_maxed(def, lvl)
				price = Game.upgrade_cost(real_id)
				can = Game.money >= price
			"signal":
				var lvl := Game.sig(real_id)
				lvl_l.text = "LV %d" % lvl
				maxed = Game.is_maxed(def, lvl)
				price = Game.signal_cost(real_id)
				can = Game.signal_pts >= price
		if maxed:
			price_l.text = "MAX"
			price_l.add_theme_color_override("font_color", ThemeBuilder.DIM)
			btn.disabled = true
		else:
			price_l.text = ("%d SIG" % int(price)) if row["kind"] == "signal" else "$" + Game.fmt(price)
			var col := (ThemeBuilder.APPROVAL if row["kind"] == "signal" else ThemeBuilder.MONEY) if can else ThemeBuilder.BAD
			price_l.add_theme_color_override("font_color", col)
			btn.disabled = not can
		btn.modulate.a = 1.0 if can or maxed else 0.62

	_signal_big.text = "Signal: %d" % Game.signal_pts
	_harvest_btn.disabled = not Game.goal_reached()
	_harvest_btn.text = ("HARVEST  (+%d Signal)" % Game.signal_gain()) if Game.goal_reached() else "Harvest at $%s earned" % Game.fmt(Game.season_goal())
	_stats.text = "Crop circles: %d\nPerfect circles: %d\nCows abducted: %d\nGolden wheat: %d\nSlot spins: %d  (jackpots %d)\nBest circle: $%s\nTotal earned: $%s" % [
		int(Game.stats["circles"]), int(Game.stats["perfect"]), int(Game.stats["cows"]), int(Game.stats["golden"]),
		int(Game.stats["spins"]), int(Game.stats["jackpots"]), Game.fmt(float(Game.stats["best"])), Game.fmt(float(Game.stats["earned"]))]


func _prev_alien_name(id: String) -> String:
	for i in Defs.ALIENS.size():
		if Defs.ALIENS[i]["id"] == id and i > 0:
			return Defs.ALIENS[i - 1]["name"]
	return "crew"
