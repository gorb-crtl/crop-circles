extends Node
## Headless smoke test. Run:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = pass. NOTE: wipes your local save.

var _fails := 0


func check(cond: bool, what: String) -> void:
	print("  ok   " if cond else "  FAIL ", what)
	if not cond:
		_fails += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func draw_circle_with_hand(main, center: Vector2, r: float) -> void:
	var path := Aliens.circle_path(center, r)
	for k in range(1, path.size()):
		main._stamp_hand(path[k - 1], path[k])


func _ready() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.menu.is_open(), "title menu shows on start")
	await wait(3.0)
	main._on_play(true)
	await get_tree().process_frame
	check(main.playing, "new game starts")
	var field: Field = main.field

	var before := Game.money
	draw_circle_with_hand(main, Vector2(40, 40), 9.0)
	await wait(0.4)
	check(field.circles.size() >= 1, "closing a loop makes a crop circle (%d)" % field.circles.size())
	check(Game.money > before, "crop circle pays out ($%.2f)" % Game.money)
	if field.circles.size() > 0:
		var c: Dictionary = field.circles.values()[0]
		print("     kind=%s area=%d" % [c["kind"], c["area"]])

	# A line touching nothing closed shouldn't make a circle.
	var n := field.circles.size()
	main._stamp_hand(Vector2(100, 20), Vector2(150, 40))
	await wait(0.4)
	check(field.circles.size() == n, "an open line is not a circle")

	# Crew.
	Game.money = 1e6
	check(Game.buy_alien("greeblet"), "buy a greeblet")
	check(Game.buy_alien("spinner"), "buy a spinner")
	check(main.aliens.crew_count() == 2, "crew appear on the field")
	var circles_before := int(Game.stats["circles"])
	await wait(9.0)
	check(int(Game.stats["circles"]) > circles_before, "crew make circles on their own (%d)" % (int(Game.stats["circles"]) - circles_before))

	for u in Defs.UPGRADES:
		Game.buy_upgrade(u["id"])
	check(Game.lvl("hand") == 1, "upgrades buy")

	# Slot.
	main._open_slot()
	check(main.hud.slot.visible, "slot opens")
	var m0 := Game.money
	main.hud.slot.spin()
	check(Game.money < m0, "spin takes the bet")
	await wait(2.6)
	check(not main.hud.slot.spinning, "reels stop")
	main.hud.slot.close_slot()
	check(not main.hud.slot.visible, "slot closes")

	# Expiry + regrowth.
	Game.upgrades["memory"] = 0
	for s in field.circles:
		field.circles[s]["age"] = 999.0
	await wait(0.3)
	check(field.circles.size() <= 2, "old circles expire")

	# Save / load.
	Game.save_game()
	var money := Game.money
	Game.money = 0
	Game.load_game()
	check(absf(Game.money - money) < 1.0, "save/load keeps money")

	# Harvest through all seasons.
	for s in Game.SEASON_COUNT:
		Game.earn(Game.season_goal() * 1.2)
		check(Game.goal_reached(), "season %d goal reached" % (s + 1))
		main._start_harvest()
		var t := 0.0
		while main.harvesting and t < 15.0:
			await wait(0.25)
			t += 0.25
		check(not main.harvesting, "harvest %d finishes" % (s + 1))
		main.hud._popup_bg.visible = false
	check(Game.won, "seven harvests win the game (signal %d)" % Game.signal_pts)
	check(Game.buy_signal("boost"), "signal upgrade buys")

	# Pause + title.
	main._pause()
	check(get_tree().paused and main.menu.mode == "pause", "pause menu")
	main.menu.resume()
	check(not get_tree().paused, "resume")
	main._to_title()
	check(main.menu.mode == "title", "back to title")

	Game.wipe()
	print("FAILS: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
