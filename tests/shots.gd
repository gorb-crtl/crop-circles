extends Node
## Takes screenshots into docs/ (needs a display: xvfb-run works).
## godot --path . --rendering-driver opengl3 res://tests/shots.tscn

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/%s.png" % name)
	print("saved ", name)


func wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _ready() -> void:
	Game.wipe()
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(4.0)
	await shot("title")
	main._on_play(true)
	Game.money = 5e5
	for i in 6:
		Game.buy_alien("greeblet")
	for i in 3:
		Game.buy_alien("spinner")
	Game.buy_alien("tracer")
	Game.buy_alien("tracer")
	Game.buy_alien("glowie")
	for u in ["tourists", "magnet", "magnet", "golden", "hand", "hand"]:
		Game.buy_upgrade(u)
	var path := Aliens.circle_path(Vector2(70, 60), 14.0)
	for k in range(1, path.size()):
		main._stamp_hand(path[k - 1], path[k])
	main._stamp_hand(Vector2(120, 30), Vector2(160, 70))
	await wait(9.0)
	var p2 := Aliens.circle_path(Vector2(150, 95), 10.0)
	for k in range(1, p2.size()):
		main._stamp_hand(p2[k - 1], p2[k])
	await wait(0.5)
	await shot("game")
	main._open_slot()
	main.hud.slot.spin()
	await wait(3.0)
	await shot("slot")
	main.hud.slot.close_slot()
	main._pause()
	main.menu._open_options("pause")
	await wait(0.5)
	await shot("options")
	Game.wipe()
	get_tree().quit()
