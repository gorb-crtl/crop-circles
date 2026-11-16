class_name Table
extends Node2D
## The tabletop the wheat field sits on: wooden planks, a warm lamp glow,
## the field's dirt rim and fence, the barn, and the Mothership Slot machine.

const SCREEN := Vector2(1280, 720)

var field_rect := Rect2()
var slot_pos := Vector2(36, 300)
var slot_hover := false
var farmer_visible := false
var farmer_x := 0.0

var _slot_tex: Texture2D = preload("res://assets/sprites/slot.png")
var _barn_tex: Texture2D = preload("res://assets/sprites/barn.png")
var _farmer_tex: Texture2D = preload("res://assets/sprites/farmer.png")
var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")
var _time := 0.0
var _slot_flash := 0.0


func slot_rect() -> Rect2:
	return Rect2(slot_pos, _slot_tex.get_size() * Game.CELL)


func flash_slot() -> void:
	_slot_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	_slot_flash = maxf(0.0, _slot_flash - delta)
	queue_redraw()


func _hash(x: int, y: int) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	var cell := Game.CELL
	# Planks.
	var plank_h := 44.0
	var y := 0.0
	var row := 0
	while y < SCREEN.y:
		var shade := 0.115 + 0.018 * _hash(row, 3)
		draw_rect(Rect2(0, y, SCREEN.x, plank_h), Color(shade * 1.35, shade, shade * 0.78))
		draw_rect(Rect2(0, y + plank_h - cell, SCREEN.x, cell), Color(0.05, 0.035, 0.03))
		# Grain streaks.
		for k in 14:
			var gx := floorf(_hash(row, k) * SCREEN.x / cell) * cell
			var gy := y + floorf(_hash(k, row) * (plank_h - 2 * cell) / cell) * cell
			var gw := floorf((30 + _hash(row + k, 7) * 120) / cell) * cell
			draw_rect(Rect2(gx, gy, gw, cell), Color(0.19, 0.13, 0.09, 0.55))
		# Seams between boards.
		var seam := floorf(_hash(row, 11) * 900 / cell) * cell + 100
		draw_rect(Rect2(seam, y, cell, plank_h), Color(0.05, 0.035, 0.03))
		y += plank_h
		row += 1

	# Warm lamp light, in stepped pixel bands.
	var center := field_rect.get_center()
	for i in 6:
		var r := 700.0 - i * 95.0
		_pixel_ellipse(center, Vector2(r, r * 0.72), Color(1.0, 0.75, 0.4, 0.035))

	# Field rim: soil, then a fence.
	var rim := field_rect.grow(3 * cell)
	draw_rect(rim.grow(cell), Color(0.04, 0.03, 0.03, 0.6))
	draw_rect(rim, Color(0.20, 0.13, 0.08))
	for i in 220:
		var px := rim.position.x + floorf(_hash(i, 1) * rim.size.x / cell) * cell
		var py := rim.position.y + floorf(_hash(1, i) * rim.size.y / cell) * cell
		draw_rect(Rect2(px, py, cell, cell), Color(0.27, 0.18, 0.11))
	_fence(rim.grow(cell))

	# Barn.
	draw_texture_rect(_barn_tex, Rect2(Vector2(44, 112), _barn_tex.get_size() * cell), false)
	if farmer_visible:
		draw_texture_rect(_farmer_tex, Rect2(Vector2(farmer_x, 168), _farmer_tex.get_size() * cell), false)

	# Mothership Slot.
	var sr := slot_rect()
	draw_rect(Rect2(sr.position + Vector2(cell * 2, sr.size.y - cell), Vector2(sr.size.x - cell * 3, cell * 2)), Color(0, 0, 0, 0.35))
	if slot_hover:
		draw_rect(sr.grow(cell), Color(0.5, 1.0, 0.85, 0.18))
	draw_texture_rect(_slot_tex, Rect2(sr.position, sr.size), false)
	# Chasing lights on the dome.
	var lights := [Vector2(5, 3), Vector2(9, 3), Vector2(13, 3), Vector2(17, 3)]
	for i in lights.size():
		var on := (int(_time * 6.0) + i) % 4 == 0 or _slot_flash > 0.0 and int(_time * 20.0) % 2 == 0
		var col := Color(1, 0.95, 0.5) if on else Color(0.5, 0.4, 0.2)
		draw_rect(Rect2(sr.position + (lights[i] + Vector2(1, 1)) * cell, Vector2(cell, cell)), col)
	var label := "MOTHERSHIP SLOT"
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var bob := roundf(sin(_time * 2.5) * 1.5)
	draw_string_outline(_font, Vector2(sr.get_center().x - w * 0.5, sr.position.y - 8 + bob), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 4, Color(0.02, 0.02, 0.04))
	draw_string(_font, Vector2(sr.get_center().x - w * 0.5, sr.position.y - 8 + bob), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.4) if slot_hover else Color(0.85, 0.8, 0.7))


func _fence(r: Rect2) -> void:
	var cell := Game.CELL
	var post := Color(0.38, 0.26, 0.16)
	var post_hi := Color(0.52, 0.37, 0.23)
	var rail := Color(0.30, 0.20, 0.12)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, cell), rail)
	draw_rect(Rect2(r.position.x, r.end.y - cell, r.size.x, cell), rail)
	draw_rect(Rect2(r.position.x, r.position.y, cell, r.size.y), rail)
	draw_rect(Rect2(r.end.x - cell, r.position.y, cell, r.size.y), rail)
	var x := r.position.x
	while x <= r.end.x:
		for yy in [r.position.y, r.end.y - cell]:
			draw_rect(Rect2(x - cell, yy - cell, cell * 2, cell * 3), post)
			draw_rect(Rect2(x - cell, yy - cell, cell, cell), post_hi)
		x += cell * 16
	var y := r.position.y
	while y <= r.end.y:
		for xx in [r.position.x, r.end.x - cell]:
			draw_rect(Rect2(xx - cell * 0.5, y - cell, cell * 2, cell * 2), post)
		y += cell * 16


func _pixel_ellipse(c: Vector2, radii: Vector2, col: Color) -> void:
	var cell := Game.CELL * 2
	var rows := int(radii.y / cell)
	for k in range(-rows, rows + 1):
		var yy := k * cell
		var half := radii.x * sqrt(maxf(0.0, 1.0 - (yy * yy) / (radii.y * radii.y)))
		half = floorf(half / cell) * cell
		draw_rect(Rect2(floorf((c.x - half) / cell) * cell, floorf((c.y + yy) / cell) * cell, half * 2, cell), col)
