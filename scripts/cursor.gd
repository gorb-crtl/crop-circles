class_name GameCursor
extends CanvasLayer
## Draws the chosen cursor on top of everything (above the CRT, so it stays
## crisp). Styles: hand, dot, arrow (system cursor), triangle, square, hexagon.
## Pick one in Options; saved in Game.cursor.

var _node: Node2D
var _press := 0.0
var _hand: Texture2D = preload("res://assets/sprites/cursor_hand.png")
var _fist: Texture2D = preload("res://assets/sprites/cursor_fist.png")


func _ready() -> void:
	layer = 100
	_node = Node2D.new()
	_node.draw.connect(_draw_cursor)
	add_child(_node)
	Game.settings_changed.connect(_apply)
	_apply()


func _apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Game.cursor == "arrow" else Input.MOUSE_MODE_HIDDEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_node.visible = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_node.visible = true


func _process(delta: float) -> void:
	_node.position = _node.get_viewport().get_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_press = minf(1.0, _press + delta * 12.0)
	else:
		_press = maxf(0.0, _press - delta * 8.0)
	_node.queue_redraw()


## Same shape drawing, used by the Options preview buttons too.
static func draw_shape(ci: CanvasItem, style: String, at: Vector2, s: float, press := 0.0, hand: Texture2D = null, fist: Texture2D = null) -> void:
	var outline := Color(0.02, 0.02, 0.05)
	var fill := Color(0.62, 1.0, 0.82)
	var k := 1.0 - press * 0.2
	match style:
		"hand":
			var tex := fist if press > 0.5 and fist else hand
			if tex:
				var sz := tex.get_size() * s * 0.5
				ci.draw_texture_rect(tex, Rect2((at - sz * 0.5 + Vector2(0, sz.y * 0.1)).floor(), sz), false)
		"dot":
			ci.draw_circle(at, 5.0 * s * 0.25 * k + 1.5, outline)
			ci.draw_circle(at, 5.0 * s * 0.25 * k, fill)
		"arrow":
			var pts := PackedVector2Array([at, at + Vector2(0, 16) * s * 0.25, at + Vector2(4.5, 12) * s * 0.25, at + Vector2(11, 11) * s * 0.25])
			ci.draw_colored_polygon(pts, fill)
			pts.append(at)
			ci.draw_polyline(pts, outline, 1.5)
		"triangle":
			var r := 9.0 * s * 0.25 * k
			var pts := PackedVector2Array()
			for i in 3:
				pts.append(at + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * r)
			_poly(ci, pts, fill, outline)
		"square":
			var r := 6.5 * s * 0.25 * k
			_poly(ci, PackedVector2Array([at + Vector2(-r, -r), at + Vector2(r, -r), at + Vector2(r, r), at + Vector2(-r, r)]), fill, outline)
		"hexagon":
			var r := 8.0 * s * 0.25 * k
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(at + Vector2.from_angle(TAU * i / 6.0) * r)
			_poly(ci, pts, fill, outline)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: Color) -> void:
	var hollow := PackedVector2Array(pts)
	hollow.append(pts[0])
	ci.draw_polyline(hollow, outline, 5.0)
	ci.draw_polyline(hollow, fill, 2.5)
	ci.draw_circle(pts[0].lerp(pts[pts.size() / 2], 0.5), 1.5, fill)


func _draw_cursor() -> void:
	if Game.cursor == "arrow":
		return
	draw_shape(_node, Game.cursor, Vector2.ZERO, 4.0, _press, _hand, _fist)
