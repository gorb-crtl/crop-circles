class_name Field
extends Node2D
## The wheat field: a grid of wheat cells drawn by shaders/field.gdshader.
## Anything (your hand, aliens, saucers) flattens wheat with stamp()/stamp_line().
## A few times a second we look for standing wheat that has been completely
## fenced in by flattened wheat. Each such pocket becomes a crop circle: it
## locks in, swirls, glows, pays out (see main.gd), then grows back later.

signal circle_locked(circle: Dictionary)
signal circle_expired(circle: Dictionary)

const W := 190
const H := 125
const MIN_AREA := 8            # smaller pockets just get squashed
const LOOSE_LIFE := 9.0        # seconds before stray flattened wheat stands back up
const REVEAL_SPEED := 40.0     # cells per second for the swirl animation
const ST_STAND := 0
const ST_FLAT := 1
const ST_LOCK := 2
## Owners (who flattened a cell): 0 = player, 1.. = alien type index + 1.
const OWNER_PLAYER := 0

var state := PackedByteArray()
var dir := PackedByteArray()
var golden := PackedByteArray()
var cell_owner := PackedByteArray()
var cid := PackedInt32Array()
var regrow_at := PackedFloat32Array()
var growth := PackedFloat32Array()

var circles: Dictionary = {}   # slot -> circle dict
var last_shape: PackedVector2Array = []  # outline offsets of the last player circle
var hover_cell := Vector2(-100, -100)
var hover_radius := 0.0
var show_hover := false
var paused := false

var _pix := PackedByteArray()
var _img: Image
var _tex: ImageTexture
var _circ_img: Image
var _circ_tex: ImageTexture
var _sprite: Sprite2D
var _dirty := false
var _detect_dirty := false
var _detect_timer := 0.0
var _time := 0.0
var _loose_q_t := PackedFloat32Array()
var _loose_q_i := PackedInt32Array()
var _loose_head := 0
var _growing := PackedInt32Array()
var _golden_timer := 0.0
var _golden_cells := PackedInt32Array()
var _mark := PackedByteArray()
var _queue := PackedInt32Array()


func _ready() -> void:
	var n := W * H
	state.resize(n)
	dir.resize(n)
	golden.resize(n)
	cell_owner.resize(n)
	cid.resize(n)
	regrow_at.resize(n)
	growth.resize(n)
	_pix.resize(n * 4)
	_mark.resize(n)
	_queue.resize(n)
	for i in n:
		cid[i] = -1
		growth[i] = 255.0
		dir[i] = randi() % 256
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_circ_img = Image.create(256, 1, false, Image.FORMAT_RGBA8)
	_circ_tex = ImageTexture.create_from_image(_circ_img)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _tex
	_sprite.scale = Vector2(Game.CELL, Game.CELL)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/field.gdshader")
	mat.set_shader_parameter("circ_tex", _circ_tex)
	mat.set_shader_parameter("size", Vector2(W, H))
	_sprite.material = mat
	add_child(_sprite)
	for i in n:
		_put(i)
	_upload()


func size_px() -> Vector2:
	return Vector2(W, H) * Game.CELL


func rect() -> Rect2:
	return Rect2(position, size_px())


func world_to_cell(p: Vector2) -> Vector2:
	return (p - position) / Game.CELL


func cell_to_world(c: Vector2) -> Vector2:
	return position + c * Game.CELL


func in_field(c: Vector2) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func is_standing(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H and state[y * W + x] == ST_STAND


## Fraction of standing wheat in a disc (rough; samples a grid).
func standing_fraction(center: Vector2, r: float) -> float:
	var total := 0
	var ok := 0
	var step := maxf(1.0, r / 4.0)
	var y := -r
	while y <= r:
		var x := -r
		while x <= r:
			if x * x + y * y <= r * r:
				total += 1
				var c := center + Vector2(x, y)
				if is_standing(int(c.x), int(c.y)):
					ok += 1
			x += step
		y += step
	return float(ok) / maxf(1.0, total)


# ---------------------------------------------------------------- stamping

## Flattens the wheat in a disc (cell coords). Returns how many stalks fell.
func stamp(c: Vector2, radius: float, angle: float, who: int) -> int:
	if paused:
		return 0
	var r := int(ceil(radius))
	var cx := int(floor(c.x))
	var cy := int(floor(c.y))
	var r2 := radius * radius
	var d := int(fposmod(angle / TAU, 1.0) * 255.0)
	var fell := 0
	for y in range(cy - r, cy + r + 1):
		if y < 0 or y >= H:
			continue
		for x in range(cx - r, cx + r + 1):
			if x < 0 or x >= W:
				continue
			var dx := x + 0.5 - c.x
			var dy := y + 0.5 - c.y
			if dx * dx + dy * dy > r2 + 0.3:
				continue
			var i := y * W + x
			var s := state[i]
			if s == ST_LOCK:
				continue
			if s == ST_STAND:
				fell += 1
			state[i] = ST_FLAT
			dir[i] = d
			cell_owner[i] = who
			_set_loose_timer(i)
			_put(i)
	if fell > 0:
		_dirty = true
		_detect_dirty = true
	return fell


func stamp_line(a: Vector2, b: Vector2, radius: float, who: int) -> int:
	var dist := a.distance_to(b)
	var steps := maxi(1, int(ceil(dist / 0.5)))
	var ang := (b - a).angle() if dist > 0.01 else randf() * TAU
	var fell := 0
	for s in range(1, steps + 1):
		fell += stamp(a.lerp(b, float(s) / steps), radius, ang, who)
	return fell


func _set_loose_timer(i: int) -> void:
	var t := _time + LOOSE_LIFE + randf() * 2.0
	regrow_at[i] = t
	_loose_q_t.append(t)
	_loose_q_i.append(i)


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	_time += delta
	if not paused:
		_regrow_loose()
		_detect_timer -= delta
		if _detect_dirty and _detect_timer <= 0.0:
			_detect_timer = 0.12
			_detect_dirty = false
			detect()
		_golden_timer -= delta
		if _golden_timer <= 0.0:
			_golden_timer = randf_range(2.0, 4.0)
			_spawn_golden()
	_update_growing(delta)
	_update_circles(delta)
	if _dirty:
		_upload()
	queue_redraw()


func _regrow_loose() -> void:
	while _loose_head < _loose_q_t.size() and _loose_q_t[_loose_head] <= _time:
		var i := _loose_q_i[_loose_head]
		if state[i] == ST_FLAT and absf(regrow_at[i] - _loose_q_t[_loose_head]) < 0.001:
			state[i] = ST_STAND
			growth[i] = 0.0
			_growing.append(i)
			_put(i)
			_dirty = true
		_loose_head += 1
	if _loose_head > 4096:
		_loose_q_t = _loose_q_t.slice(_loose_head)
		_loose_q_i = _loose_q_i.slice(_loose_head)
		_loose_head = 0


func _update_growing(delta: float) -> void:
	if _growing.is_empty():
		return
	var keep := PackedInt32Array()
	for i in _growing:
		if state[i] != ST_STAND:
			continue
		growth[i] += delta * 180.0
		if growth[i] < 255.0:
			keep.append(i)
		else:
			growth[i] = 255.0
		_put(i)
	_growing = keep
	_dirty = true


func _update_circles(delta: float) -> void:
	if circles.is_empty():
		return
	var expired: Array = []
	for slot in circles:
		var c: Dictionary = circles[slot]
		c["age"] = float(c["age"]) + delta
		var age: float = c["age"]
		var life: float = c["life"]
		var reveal := minf(age * REVEAL_SPEED, float(c["max_r"]) + 3.0)
		var reveal_b := 255 if reveal >= float(c["max_r"]) + 3.0 else int(clampf(reveal, 0, 249))
		var glow := 1.0 - minf(age, 1.2) / 1.2 * 0.55
		glow += 0.08 * sin(_time * 3.0 + float(slot))
		if float(c.get("aura", 1.0)) > 1.0:
			glow += 0.15
		if age > life - 2.0:
			glow *= clampf((life - age) / 2.0, 0.0, 1.0)
		var center: Vector2 = c["center"]
		_circ_img.set_pixel(slot, 0, Color8(int(round(center.x)), int(round(center.y)), reveal_b, int(clampf(glow, 0.0, 1.0) * 255.0)))
		if age >= life:
			expired.append(slot)
	for slot in expired:
		_expire(slot)
	_circ_tex.update(_circ_img)


func _expire(slot: int) -> void:
	var c: Dictionary = circles[slot]
	circles.erase(slot)
	for i in (c["cells"] as PackedInt32Array):
		if cid[i] == slot:
			state[i] = ST_STAND
			cid[i] = -1
			growth[i] = -randf() * 120.0
			_growing.append(i)
			_put(i)
	_dirty = true
	_detect_dirty = true
	circle_expired.emit(c)


## Clears everything (new season). Wheat grows back in a wave from the left.
func reset_field() -> void:
	for slot in circles.keys():
		circles.erase(slot)
	_growing = PackedInt32Array()
	for y in H:
		for x in W:
			var i := y * W + x
			state[i] = ST_STAND
			cid[i] = -1
			golden[i] = 0
			growth[i] = -x * 2.2 - randf() * 30.0
			dir[i] = randi() % 256
			_growing.append(i)
			_put(i)
	_golden_cells = PackedInt32Array()
	_loose_q_t = PackedFloat32Array()
	_loose_q_i = PackedInt32Array()
	_loose_head = 0
	_dirty = true


## Harvester pass: everything left of column x gets cut down.
func cut_to(x_cell: int) -> void:
	x_cell = mini(x_cell, W - 1)
	for y in H:
		for x in range(maxi(0, x_cell - 3), x_cell + 1):
			var i := y * W + x
			if state[i] == ST_LOCK:
				continue
			state[i] = ST_FLAT
			regrow_at[i] = 1e9
			golden[i] = 0
			dir[i] = 64
			_put(i)
	_dirty = true


# ---------------------------------------------------------------- golden

func _spawn_golden() -> void:
	var keep := PackedInt32Array()
	for i in _golden_cells:
		if golden[i] == 1 and state[i] == ST_STAND:
			keep.append(i)
	_golden_cells = keep
	if _golden_cells.size() >= Game.golden_max() * 3:
		return
	for attempt in 10:
		var x := randi_range(6, W - 7)
		var y := randi_range(6, H - 7)
		if state[y * W + x] != ST_STAND:
			continue
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var i := (y + o.y) * W + x + o.x
			if state[i] == ST_STAND:
				golden[i] = 1
				_golden_cells.append(i)
				_put(i)
		_dirty = true
		return


## Slot prize: scatter extra golden wheat right now.
func spawn_golden(n: int) -> void:
	for k in n:
		for attempt in 10:
			var x := randi_range(6, W - 7)
			var y := randi_range(6, H - 7)
			var i := y * W + x
			if state[i] == ST_STAND:
				golden[i] = 1
				_golden_cells.append(i)
				_put(i)
				break
	_dirty = true


func golden_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in _golden_cells:
		if golden[i] == 1 and state[i] == ST_STAND:
			out.append(cell_to_world(Vector2(i % W + 0.5, i / W + 0.5)))
	return out


# ---------------------------------------------------------------- detection

## Finds pockets of standing wheat that can't reach the edge of the field.
func detect() -> void:
	var n := W * H
	_mark.fill(0)
	var head := 0
	var tail := 0
	# Seed with standing wheat on the border.
	for x in W:
		for y in [0, H - 1]:
			var i: int = y * W + x
			if state[i] == ST_STAND and _mark[i] == 0:
				_mark[i] = 1
				_queue[tail] = i
				tail += 1
	for y in range(1, H - 1):
		for x in [0, W - 1]:
			var i: int = y * W + x
			if state[i] == ST_STAND and _mark[i] == 0:
				_mark[i] = 1
				_queue[tail] = i
				tail += 1
	while head < tail:
		var i := _queue[head]
		head += 1
		var x := i % W
		if x > 0 and _mark[i - 1] == 0 and state[i - 1] == ST_STAND:
			_mark[i - 1] = 1
			_queue[tail] = i - 1
			tail += 1
		if x < W - 1 and _mark[i + 1] == 0 and state[i + 1] == ST_STAND:
			_mark[i + 1] = 1
			_queue[tail] = i + 1
			tail += 1
		if i >= W and _mark[i - W] == 0 and state[i - W] == ST_STAND:
			_mark[i - W] = 1
			_queue[tail] = i - W
			tail += 1
		if i < n - W and _mark[i + W] == 0 and state[i + W] == ST_STAND:
			_mark[i + W] = 1
			_queue[tail] = i + W
			tail += 1
	# Anything standing and unmarked is fenced in. Group into pockets.
	for start in n:
		if state[start] != ST_STAND or _mark[start] != 0:
			continue
		head = 0
		tail = 0
		_mark[start] = 2
		_queue[0] = start
		tail = 1
		var cells := PackedInt32Array()
		while head < tail:
			var i := _queue[head]
			head += 1
			cells.append(i)
			var x := i % W
			for j in [i - 1 if x > 0 else -1, i + 1 if x < W - 1 else -1, i - W, i + W]:
				if j >= 0 and j < n and _mark[j] == 0 and state[j] == ST_STAND:
					_mark[j] = 2
					_queue[tail] = j
					tail += 1
		if cells.size() < MIN_AREA:
			for i in cells:
				state[i] = ST_FLAT
				golden[i] = 0
				_set_loose_timer(i)
				_put(i)
			_dirty = true
		else:
			_lock(cells)


func _lock(pocket: PackedInt32Array) -> void:
	var slot := _free_slot()
	var area := pocket.size()
	var sum := Vector2.ZERO
	var bb_min := Vector2i(W, H)
	var bb_max := Vector2i(-1, -1)
	var golds := 0
	for i in pocket:
		var p := Vector2i(i % W, i / W)
		sum += Vector2(p) + Vector2(0.5, 0.5)
		bb_min = Vector2i(mini(bb_min.x, p.x), mini(bb_min.y, p.y))
		bb_max = Vector2i(maxi(bb_max.x, p.x), maxi(bb_max.y, p.y))
		_mark[i] = 3
		if golden[i] == 1:
			golds += 1
			golden[i] = 0
	var center := sum / area
	# Shape: how evenly the pocket's edge sits around its centre.
	var dists := PackedFloat32Array()
	var outline := PackedVector2Array()
	for i in pocket:
		var x := i % W
		var edge := (x == 0 or _mark[i - 1] != 3) or (x == W - 1 or _mark[i + 1] != 3) \
			or (i < W or _mark[i - W] != 3) or (i >= W * (H - 1) or _mark[i + W] != 3)
		if edge:
			var p := Vector2(x + 0.5, i / W + 0.5)
			dists.append(p.distance_to(center))
			outline.append(p - center)
	var mean := 0.0
	for d in dists:
		mean += d
	mean /= maxf(1.0, dists.size())
	var variance := 0.0
	for d in dists:
		variance += (d - mean) * (d - mean)
	var cv := sqrt(variance / maxf(1.0, dists.size())) / maxf(mean, 0.5)
	var radius := sqrt(area / PI)

	# Who made it: most common cell_owner of the surrounding flattened wheat.
	var cells := PackedInt32Array(pocket)
	var owners := {}
	var max_r := 0.0
	for i in pocket:
		var x := i % W
		var y := i / W
		max_r = maxf(max_r, Vector2(x + 0.5, y + 0.5).distance_to(center))
		for dy in range(-2, 3):
			var yy := y + dy
			if yy < 0 or yy >= H:
				continue
			for dx in range(-2, 3):
				var xx := x + dx
				if xx < 0 or xx >= W:
					continue
				var j := yy * W + xx
				if state[j] == ST_FLAT and _mark[j] != 3:
					_mark[j] = 3
					cells.append(j)
					owners[cell_owner[j]] = int(owners.get(cell_owner[j], 0)) + 1
					max_r = maxf(max_r, Vector2(xx + 0.5, yy + 0.5).distance_to(center))
	var maker := OWNER_PLAYER
	var best := -1
	for o in owners:
		if owners[o] > best:
			best = owners[o]
			maker = o

	# Bullseye: drawn around another circle that's still showing.
	var bullseye := false
	for s in circles:
		var other: Dictionary = circles[s]
		var oc: Vector2 = other["center"]
		if oc.distance_to(center) < maxf(2.5, radius * 0.3) and float(other["radius"]) < radius * 0.85:
			bullseye = true
			other["age"] = minf(float(other["age"]), 0.0)
			break

	for i in cells:
		var p := Vector2(i % W + 0.5, i / W + 0.5) - center
		state[i] = ST_LOCK
		cid[i] = slot
		golden[i] = 0
		# Swirl: stalks lie in a spiral around the centre.
		var a := p.angle() + PI * 0.5 + p.length() * 0.12
		dir[i] = int(fposmod(a / TAU, 1.0) * 255.0)
	# Rim cells (touching the outside) get drawn brighter.
	for i in cells:
		var x := i % W
		var rim := x == 0 or x == W - 1 or i < W or i >= W * (H - 1) \
			or cid[i - 1] != slot or cid[i + 1] != slot or cid[i - W] != slot or cid[i + W] != slot
		growth[i] = 128.0 if rim else 255.0
		_put(i)
	_dirty = true

	var tol := 0.07 + 0.3 / maxf(radius, 1.0)
	var kind := "Blob"
	var mult := 1.0
	if bullseye:
		kind = "Bullseye"
		mult = 4.0
	elif cv < tol:
		kind = "Perfect Circle"
		mult = 3.0
	elif cv < tol * 2.0:
		kind = "Round Circle"
		mult = 1.8
	elif cv < tol * 3.5:
		kind = "Crop Circle"
		mult = 1.25
	if maker == 3 and mult < 2.0:   # tracer (alien index 2) + 1
		kind = "Alien Glyph"
		mult = 2.0

	if maker == OWNER_PLAYER:
		last_shape = outline
	var circle := {
		"slot": slot,
		"cells": cells,
		"area": area,
		"center": center,
		"radius": radius,
		"max_r": max_r,
		"age": 0.0,
		"life": Game.circle_life(),
		"kind": kind,
		"mult": mult,
		"maker": maker,
		"golden": golds,
		"tourist_acc": 0.0,
		"pocket": pocket,
	}
	circles[slot] = circle
	circle_locked.emit(circle)


func _free_slot() -> int:
	for s in range(1, 256):
		if not circles.has(s):
			return s
	# Field is full of circles: retire the oldest.
	var oldest := 1
	for s in circles:
		if float(circles[s]["age"]) > float(circles[oldest]["age"]):
			oldest = s
	_expire(oldest)
	return oldest


## Is this cell inside a crop circle's pocket?
func circle_at(c: Vector2) -> Dictionary:
	if not in_field(c):
		return {}
	var s := cid[int(c.y) * W + int(c.x)]
	return circles.get(s, {})


# ---------------------------------------------------------------- texture

func _put(i: int) -> void:
	var o := i * 4
	var s := state[i]
	if s == ST_STAND:
		_pix[o] = 0
		_pix[o + 2] = 255 if golden[i] == 1 else 0
	elif s == ST_FLAT:
		_pix[o] = 120
		_pix[o + 2] = 0
	else:
		_pix[o] = 255
		_pix[o + 2] = maxi(cid[i], 0)
	_pix[o + 1] = dir[i]
	_pix[o + 3] = int(clampf(growth[i], 0.0, 255.0))


func _upload() -> void:
	_img.set_data(W, H, false, Image.FORMAT_RGBA8, _pix)
	_tex.update(_img)
	_dirty = false


func _draw() -> void:
	if not show_hover:
		return
	# Brush outline in field pixels.
	var cell := Game.CELL
	var r := hover_radius
	var steps := maxi(12, int(r * 8.0))
	var last := Vector2i(-999, -999)
	var col := Color(0.75, 1.0, 0.9, 0.55)
	for k in steps:
		var p := hover_cell + Vector2.from_angle(TAU * k / steps) * (r + 0.6)
		var pi := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if pi != last:
			draw_rect(Rect2(Vector2(pi) * cell, Vector2(cell, cell)), col)
			last = pi
