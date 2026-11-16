class_name Effects
extends Node2D
## Cheap visual effects drawn in one node, all on the field's pixel grid:
## chaff, coins, flashes, rings, sparkles, beams and floating text.

const MAX_PARTICLES := 1500

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _col := PackedColorArray()
var _size := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _flashes: Array = []   # [pos, radius, life, max_life, color]
var _rings: Array = []     # [pos, radius, life, max_life, color]
var _sparkles: Array = []  # [pos, life, color]
var _beams: Array = []     # [pos, width, life, max_life, color]
var _pops: Array = []      # [pos, text, color, life, max_life, size]
var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")


## Bits of wheat flicked up by your hand.
func chaff(at: Vector2, amount := 2, dir := Vector2.ZERO) -> void:
	for i in amount:
		var c := Color(0.9, 0.75, 0.4) if randf() < 0.6 else Color(0.65, 0.5, 0.25)
		_add(at, dir * 60.0 + Vector2.from_angle(randf() * TAU) * randf_range(20, 90), randf_range(0.25, 0.55), c, Game.CELL, 5.0)


func coins(at: Vector2, count: int) -> void:
	for i in count:
		var c := Color(1, 0.82, 0.3) if i % 3 else Color(1, 0.96, 0.65)
		_add(at, Vector2.from_angle(randf() * TAU) * randf_range(60, 260), randf_range(0.5, 1.0), c, Game.CELL * (2 if randf() < 0.3 else 1), 3.0)


## Burst of glowing motes (circle locks).
func motes(at: Vector2, radius: float, count: int, color := Color(0.5, 1.0, 0.85)) -> void:
	for i in count:
		var p := at + Vector2.from_angle(randf() * TAU) * randf() * radius
		_add(p, Vector2(randf_range(-15, 15), randf_range(-70, -20)), randf_range(0.6, 1.4), color, Game.CELL, 1.0)


func flash(at: Vector2, radius: float, color := Color(0.7, 1, 0.9), life := 0.3) -> void:
	_flashes.append([at, radius, life, life, color])


func ring(at: Vector2, radius: float, color := Color(0.7, 1, 0.9, 0.9), life := 0.45) -> void:
	_rings.append([at, radius, life, life, color])


func sparkle(at: Vector2, color := Color(1, 1, 0.8)) -> void:
	if _sparkles.size() < 80:
		_sparkles.append([at, 0.5, color])


## Tractor beam column (abductions, saucers).
func beam(at: Vector2, width: float, life := 1.0, color := Color(0.5, 1, 0.85, 0.35)) -> void:
	_beams.append([at, width, life, life, color])


func pop(at: Vector2, text: String, color := Color.WHITE, size := 12, life := 1.0) -> void:
	if _pops.size() > 40:
		_pops.pop_front()
	_pops.append([at + Vector2(randf_range(-3, 3), 0), text, color, life, life, size])


func _add(at: Vector2, vel: Vector2, life: float, color: Color, size: float, drag: float) -> void:
	if _pos.size() >= MAX_PARTICLES:
		return
	_pos.append(at)
	_vel.append(vel)
	_life.append(life)
	_max.append(life)
	_col.append(color)
	_size.append(maxf(1.0, roundf(size / Game.CELL)) * Game.CELL)
	_drag.append(drag)


func _process(delta: float) -> void:
	var i := _pos.size() - 1
	while i >= 0:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
		else:
			_vel[i] = _vel[i] * maxf(0.0, 1.0 - _drag[i] * delta)
			_pos[i] = _pos[i] + _vel[i] * delta
		i -= 1
	for list in [_flashes, _rings, _beams]:
		for f in list:
			f[2] -= delta
	_flashes = _flashes.filter(func(f): return f[2] > 0.0)
	_rings = _rings.filter(func(f): return f[2] > 0.0)
	_beams = _beams.filter(func(f): return f[2] > 0.0)
	for sp in _sparkles:
		sp[1] -= delta
	_sparkles = _sparkles.filter(func(sp): return sp[1] > 0.0)
	for p in _pops:
		p[3] -= delta
		p[0] = (p[0] as Vector2) + Vector2(0, -34.0 * delta)
	_pops = _pops.filter(func(p): return p[3] > 0.0)
	queue_redraw()


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_max[i] = _max[last]
	_col[i] = _col[last]
	_size[i] = _size[last]
	_drag[i] = _drag[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_max.resize(last)
	_col.resize(last)
	_size.resize(last)
	_drag.resize(last)


func _snap(p: Vector2) -> Vector2:
	return (p / Game.CELL).floor() * Game.CELL


func pixel_disc(center: Vector2, radius: float, c: Color) -> void:
	var cell := Game.CELL
	var cc := (center / cell).floor()
	var r := int(ceil(radius / cell))
	var r2 := (radius / cell) * (radius / cell)
	for dy in range(-r, r + 1):
		var span := int(floor(sqrt(maxf(0.0, r2 - dy * dy))))
		if dy * dy > r2:
			continue
		draw_rect(Rect2((cc + Vector2(-span, dy)) * cell, Vector2(span * 2 + 1, 1) * cell), c)


func pixel_ring(center: Vector2, radius: float, c: Color) -> void:
	var cell := Game.CELL
	var cc := center / cell
	var steps := maxi(10, int(radius / cell * 7.0))
	var last := Vector2(INF, INF)
	for i in steps:
		var p := (cc + Vector2.from_angle(TAU * i / steps) * radius / cell).floor()
		if p != last:
			draw_rect(Rect2(p * cell, Vector2(cell, cell)), c)
			last = p


func _draw() -> void:
	var cell := Game.CELL
	for b in _beams:
		var t: float = b[2] / b[3]
		var c: Color = b[4]
		c.a *= sin(t * PI)
		var w: float = b[1] * (0.6 + 0.4 * sin(t * PI))
		var p: Vector2 = b[0]
		draw_rect(Rect2(_snap(Vector2(p.x - w * 0.5, -40)), Vector2(roundf(w / cell) * cell, p.y + 40)), c)
		draw_rect(Rect2(_snap(Vector2(p.x - w * 0.25, -40)), Vector2(roundf(w * 0.5 / cell) * cell, p.y + 40)), Color(c, c.a * 0.8))
	for f in _flashes:
		var t: float = f[2] / f[3]
		var c: Color = f[4]
		c.a = t * 0.7
		pixel_disc(f[0], f[1] * (1.3 - 0.3 * t), c)
	for i in _pos.size():
		var c := _col[i]
		c.a *= clampf(_life[i] / (_max[i] * 0.4), 0.0, 1.0)
		draw_rect(Rect2(_snap(_pos[i]), Vector2(_size[i], _size[i])), c)
	for r in _rings:
		var t: float = 1.0 - r[2] / r[3]
		var c: Color = r[4]
		c.a *= 1.0 - t
		pixel_ring(r[0], (r[1] as float) * (0.3 + 0.9 * t), c)
	for sp in _sparkles:
		var t: float = sp[1] / 0.5
		var c: Color = sp[2]
		c.a = sin(t * PI)
		var p := _snap(sp[0])
		draw_rect(Rect2(p, Vector2(cell, cell)), c)
		if t > 0.25 and t < 0.75:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(p + d * cell, Vector2(cell, cell)), Color(c, c.a * 0.6))
	for p in _pops:
		var t: float = p[3] / p[4]
		var c: Color = p[2]
		c.a = clampf(t * 2.5, 0.0, 1.0)
		var punch := 1.0 + 0.6 * maxf(0.0, (t - 0.8) * 5.0)
		draw_set_transform(p[0], 0, Vector2(punch, punch))
		var size: int = p[5]
		var w := _font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(_font, Vector2(-w * 0.5, 0), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0.02, 0.02, 0.04, c.a))
		draw_string(_font, Vector2(-w * 0.5, 0), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	draw_set_transform(Vector2.ZERO)
