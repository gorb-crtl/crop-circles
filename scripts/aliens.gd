class_name Aliens
extends Node2D
## Your crew (bought in the shop), the cows, and visiting saucers.
## Crew walk to a patch of standing wheat and trace a closed shape through it;
## the field notices the closed loop and turns it into a crop circle.
## Only a handful of each type is shown on screen; extra crew make the ones
## you see earn more (see maker_bonus()).

const TYPES: Array = ["greeblet", "spinner", "tracer", "glowie", "saucer"]
const VISIBLE_CAP := {"greeblet": 10, "spinner": 6, "tracer": 4, "glowie": 4, "saucer": 2}
const SPEED := {"greeblet": 7.0, "spinner": 11.0, "tracer": 10.0, "glowie": 3.5, "saucer": 30.0}
const GLOW_RADIUS := 24.0

var field: Field
var fx: Effects
var demo := false   # title screen: a few crew draw circles for show

var _crew: Array = []
var _cows: Array = []
var _tex := {}
var _frames := {}
var _time := 0.0


func _ready() -> void:
	for t in TYPES + ["cow"]:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % t)
		_tex[t] = tex
		_frames[t] = 1 if t == "saucer" else 2


func type_index(t: String) -> int:
	return TYPES.find(t)


func shown(t: String) -> int:
	if demo:
		return {"greeblet": 3, "spinner": 1, "tracer": 0, "glowie": 0, "saucer": 0}[t]
	return mini(Game.count(t), VISIBLE_CAP[t])


## Extra crew beyond what's on screen multiply what the visible ones earn.
func maker_bonus(owner_id: int) -> float:
	if owner_id <= 0 or owner_id > TYPES.size():
		return 1.0
	var t: String = TYPES[owner_id - 1]
	var s := shown(t)
	if s <= 0 or demo:
		return 1.0
	return float(Game.count(t)) / s


func glow_mult(cell: Vector2) -> float:
	var m := 1.0
	for a in _crew:
		if a["type"] == "glowie" and (a["pos"] as Vector2).distance_to(cell) <= GLOW_RADIUS:
			m += maker_bonus(type_index("glowie") + 1)
	return m


func crew_count() -> int:
	return _crew.size()


# ---------------------------------------------------------------- sync

## Make the crew on screen match what you own.
func sync() -> void:
	for t in TYPES:
		var want := shown(t)
		var have := 0
		for a in _crew:
			if a["type"] == t and not a.get("once", false):
				have += 1
		while have < want:
			_crew.append(_new_agent(t))
			have += 1
		while have > want:
			for i in range(_crew.size() - 1, -1, -1):
				if _crew[i]["type"] == t and not _crew[i].get("once", false):
					_crew.remove_at(i)
					break
			have -= 1
	var cows_alive := 0
	for c in _cows:
		cows_alive += 1
	while cows_alive < Game.cow_count():
		_cows.append(_new_cow())
		cows_alive += 1
	while cows_alive > Game.cow_count():
		_cows.pop_back()
		cows_alive -= 1


func clear_all() -> void:
	_crew.clear()


func _new_agent(t: String) -> Dictionary:
	var a := {
		"type": t,
		"pos": Vector2(randf_range(10, Field.W - 10), randf_range(10, Field.H - 10)),
		"state": "rest",
		"rest": randf_range(0.2, 1.5),
		"path": PackedVector2Array(),
		"seg": 0,
		"target": Vector2.ZERO,
		"center": Vector2(-100, -100),
		"anim": randf() * 10.0,
		"flip": false,
		"alt": 0.0,
	}
	if t == "saucer":
		a["pos"] = Vector2(randf_range(0, Field.W), -30)
		a["alt"] = 1.0
		a["rest"] = randf_range(1.0, 4.0)
	return a


func _new_cow() -> Dictionary:
	return {
		"pos": Vector2(randf_range(8, Field.W - 8), randf_range(8, Field.H - 8)),
		"target": Vector2(randf_range(8, Field.W - 8), randf_range(8, Field.H - 8)),
		"state": "walk",
		"t": randf_range(1, 4),
		"anim": randf() * 5.0,
		"alpha": 1.0,
		"rise": 0.0,
	}


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	_time += delta
	for a in _crew:
		_update_agent(a, delta)
	for c in _cows:
		_update_cow(c, delta)
	remove_finished_saucers()
	queue_redraw()


func _update_agent(a: Dictionary, delta: float) -> void:
	var t: String = a["type"]
	var speed: float = SPEED[t] * Game.alien_speed()
	a["anim"] = float(a["anim"]) + delta
	match a["state"]:
		"rest":
			a["rest"] = float(a["rest"]) - delta
			if t == "saucer":
				a["alt"] = 1.0
			if float(a["rest"]) <= 0.0:
				_plan(a)
		"walk":
			if _move_to(a, a["target"], speed * (2.5 if t == "saucer" else 2.2), delta):
				if t == "glowie":
					a["state"] = "rest"
					a["rest"] = randf_range(2.0, 5.0)
				elif t == "saucer":
					a["state"] = "beam"
					a["beam_t"] = 0.0
					Sfx.play("ufo", -4.0)
				else:
					a["state"] = "draw"
					a["seg"] = 1
		"draw":
			_draw_path(a, speed, delta)
		"beam":
			a["beam_t"] = float(a["beam_t"]) + delta
			var path: PackedVector2Array = a["path"]
			var k := int(clampf(float(a["beam_t"]) / 1.1, 0.0, 1.0) * (path.size() - 1))
			var who := type_index(t) + 1
			while int(a["seg"]) <= k and int(a["seg"]) < path.size():
				field.stamp_line(path[int(a["seg"]) - 1], path[int(a["seg"])], 1.0, who)
				a["seg"] = int(a["seg"]) + 1
			if float(a["beam_t"]) > 1.5:
				a["state"] = "leave"
				a["target"] = Vector2(randf_range(-40, Field.W + 40), -40)
		"leave":
			if _move_to(a, a["target"], speed * 2.5, delta):
				a["state"] = "rest"
				a["rest"] = randf_range(4.0, 9.0)


func _move_to(a: Dictionary, target: Vector2, speed: float, delta: float) -> bool:
	var p: Vector2 = a["pos"]
	var d := target - p
	if d.length() <= speed * delta:
		a["pos"] = target
		return true
	a["pos"] = p + d.normalized() * speed * delta
	if absf(d.x) > 0.1:
		a["flip"] = d.x < 0
	return false


func _draw_path(a: Dictionary, speed: float, delta: float) -> void:
	var path: PackedVector2Array = a["path"]
	var who := type_index(a["type"]) + 1
	var brush := 0.9 if a["type"] == "spinner" else 0.75
	var budget := speed * delta
	while budget > 0.0 and int(a["seg"]) < path.size():
		var p: Vector2 = a["pos"]
		var nxt := path[int(a["seg"])]
		var d := p.distance_to(nxt)
		var q := nxt if d <= budget else p.move_toward(nxt, budget)
		budget -= minf(d, budget)
		if field.stamp_line(p, q, brush, who) > 0 and randf() < 0.25:
			fx.chaff(field.cell_to_world(q), 1)
		if absf(q.x - p.x) > 0.01:
			a["flip"] = q.x < p.x
		a["pos"] = q
		if q == nxt:
			a["seg"] = int(a["seg"]) + 1
	if int(a["seg"]) >= path.size():
		a["state"] = "rest"
		a["rest"] = randf_range(0.3, 1.2)
		a["center"] = Vector2(-100, -100)


## Pick a fresh patch of wheat and a shape to draw there.
func _plan(a: Dictionary) -> void:
	var t: String = a["type"]
	if t == "glowie":
		a["target"] = Vector2(randf_range(12, Field.W - 12), randf_range(12, Field.H - 12))
		a["state"] = "walk"
		return
	var r := 4.0
	match t:
		"greeblet":
			r = randf_range(3.0, 5.0)
		"spinner":
			r = randf_range(6.5, 10.5)
		"tracer":
			r = randf_range(6.0, 10.0)
		"saucer":
			r = randf_range(11.0, 17.0)
	var center := _find_spot(r, a["pos"] if t != "saucer" else Vector2(-1, -1))
	if center.x < 0:
		a["state"] = "rest"
		a["rest"] = randf_range(0.8, 1.6)
		return
	var path: PackedVector2Array
	if t == "tracer":
		path = _tracer_path(center, r)
	else:
		path = circle_path(center, r)
	a["path"] = path
	a["center"] = center
	a["seg"] = 1
	if t == "saucer":
		a["target"] = center
	else:
		a["target"] = path[0]
	a["state"] = "walk"


## Somewhere with lots of standing wheat, preferring spots close to "near".
func _find_spot(r: float, near := Vector2(-1, -1)) -> Vector2:
	var best := Vector2(-1, -1)
	var best_score := 0.0
	var lo := Vector2(r + 2, r + 2)
	var hi := Vector2(Field.W - r - 2, Field.H - r - 2)
	for attempt in 16:
		var c := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		if near.x >= 0 and attempt < 10:
			c = (near + Vector2.from_angle(randf() * TAU) * randf_range(r, r + 30.0)).clamp(lo, hi)
		var clash := false
		for b in _crew:
			if (b["center"] as Vector2).distance_to(c) < r + 12.0:
				clash = true
				break
		if clash:
			continue
		var s := field.standing_fraction(c, r + 1.0)
		if s >= 0.8 and near.x >= 0:
			s -= near.distance_to(c) * 0.003
		if s > best_score:
			best_score = s
			best = c
	return best if best_score >= 0.6 else Vector2(-1, -1)


static func circle_path(c: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(16, int(TAU * r / 0.9))
	var start := randf() * TAU
	for k in n + 2:
		out.append(c + Vector2.from_angle(start + TAU * k / n) * r)
	return out


static func poly_path(c: Vector2, r: float, sides: int, star := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rot := randf() * TAU
	var n := sides * (2 if star else 1)
	for k in n + 1:
		var rr := r if not star or k % 2 == 0 else r * 0.45
		out.append(c + Vector2.from_angle(rot + TAU * k / n) * rr)
	return out


func _tracer_path(c: Vector2, r: float) -> PackedVector2Array:
	var shape := field.last_shape
	if shape.size() >= 8 and randf() < 0.6:
		var pts := Array(shape)
		pts.sort_custom(func(p, q): return p.angle() < q.angle())
		var max_len := 0.0
		for p in pts:
			max_len = maxf(max_len, p.length())
		var s := minf(1.0, r / maxf(max_len, 1.0)) * 1.05
		var out := PackedVector2Array()
		for p in pts:
			out.append(c + p * s)
		out.append(out[0])
		return out
	if randf() < 0.5:
		return poly_path(c, r, 5, true)
	return poly_path(c, r, randi_range(3, 6))


## Slot machine prize: a saucer drops a giant perfect circle right now.
func giant_circle() -> void:
	var a := _new_agent("saucer")
	var r := 18.0
	var c := _find_spot(r)
	if c.x < 0:
		c = Vector2(Field.W * 0.5, Field.H * 0.5)
	a["path"] = circle_path(c, r)
	a["center"] = c
	a["target"] = c
	a["state"] = "walk"
	a["pos"] = Vector2(c.x, -30)
	a["once"] = true
	_crew.append(a)
	Sfx.play("ufo")


# ---------------------------------------------------------------- cows

func _update_cow(c: Dictionary, delta: float) -> void:
	c["anim"] = float(c["anim"]) + delta
	match c["state"]:
		"walk":
			var p: Vector2 = c["pos"]
			var d: Vector2 = (c["target"] as Vector2) - p
			if d.length() < 0.3:
				c["state"] = "graze"
				c["t"] = randf_range(2.0, 6.0)
				if randf() < 0.15:
					Sfx.play("moo", -14.0, 0.15, 3000)
			else:
				c["pos"] = p + d.normalized() * 1.6 * delta
		"graze":
			c["t"] = float(c["t"]) - delta
			if float(c["t"]) <= 0.0:
				c["state"] = "walk"
				c["target"] = Vector2(randf_range(8, Field.W - 8), randf_range(8, Field.H - 8))
		"beam":
			c["rise"] = float(c["rise"]) + delta * 14.0
			c["alpha"] = clampf(1.6 - float(c["rise"]) / 14.0, 0.0, 1.0)
			c["t"] = float(c["t"]) - delta
			if float(c["t"]) <= 0.0:
				c["state"] = "gone"
				c["t"] = randf_range(6.0, 10.0)
		"gone":
			c["t"] = float(c["t"]) - delta
			if float(c["t"]) <= 0.0:
				var fresh := _new_cow()
				fresh["pos"] = Vector2(-4 if randf() < 0.5 else Field.W + 4, randf_range(10, Field.H - 10))
				c.merge(fresh, true)


## Beams up every cow standing inside the circle's pocket. Returns how many.
func abduct_in(circle: Dictionary) -> int:
	var n := 0
	for c in _cows:
		if c["state"] != "walk" and c["state"] != "graze":
			continue
		var p: Vector2 = c["pos"]
		var hit := field.circle_at(p)
		if not hit.is_empty() and hit["slot"] == circle["slot"]:
			c["state"] = "beam"
			c["t"] = 1.6
			c["rise"] = 0.0
			n += 1
			fx.beam(field.cell_to_world(p), 9 * Game.CELL, 1.6)
	return n


## Slot "cow" result: a few extra cows trot in.
func add_cows(n: int) -> void:
	for i in n:
		var c := _new_cow()
		c["pos"] = Vector2(-4 if randf() < 0.5 else Field.W + 4, randf_range(10, Field.H - 10))
		_cows.append(c)


# ---------------------------------------------------------------- drawing

func _sprite(t: String, pos: Vector2, frame: int, flip: bool, alpha := 1.0, lift := 0.0) -> void:
	var tex: Texture2D = _tex[t]
	var frames: int = _frames[t]
	var fw := tex.get_width() / frames
	var fh := tex.get_height()
	var cell := Game.CELL
	var world := field.cell_to_world(pos)
	var origin := ((world - Vector2(fw * cell * 0.5, fh * cell + lift)) / cell).floor() * cell
	# Shadow on the wheat.
	var sh := Rect2(((world - Vector2(fw * cell * 0.35, cell)) / cell).floor() * cell, Vector2(roundf(fw * 0.7) * cell, cell * 2))
	draw_rect(sh, Color(0, 0, 0, 0.28 * alpha))
	var src := Rect2(fw * (frame % frames), 0, fw, fh)
	var dst := Rect2(origin, Vector2(fw, fh) * cell)
	if flip:
		dst = Rect2(origin + Vector2(fw * cell, 0), Vector2(-fw * cell, fh * cell))
	draw_texture_rect_region(tex, dst, src, Color(1, 1, 1, alpha))


func _draw() -> void:
	if field == null:
		return
	var cell := Game.CELL
	# Glowie auras under everything.
	for a in _crew:
		if a["type"] == "glowie":
			var pulse := 0.5 + 0.5 * sin(_time * 2.0 + float(a["anim"]))
			_dither_ring(field.cell_to_world(a["pos"]), GLOW_RADIUS * cell, Color(1, 0.95, 0.5, 0.10 + 0.08 * pulse))
	for c in _cows:
		if c["state"] == "gone":
			continue
		var walking: bool = c["state"] == "walk"
		var f := int(float(c["anim"]) * 3.0) % 2 if walking else 0
		var tgt: Vector2 = c["target"]
		_sprite("cow", c["pos"], f, tgt.x < (c["pos"] as Vector2).x, c["alpha"], float(c["rise"]) * cell)
	var ordered := _crew.duplicate()
	ordered.sort_custom(func(p, q): return (p["pos"] as Vector2).y < (q["pos"] as Vector2).y)
	for a in ordered:
		var t: String = a["type"]
		if t == "saucer":
			continue
		var moving: bool = a["state"] == "walk" or a["state"] == "draw"
		var f := int(float(a["anim"]) * 8.0) % 2 if moving else 0
		var bob := (absf(sin(float(a["anim"]) * 9.0)) * cell) if moving else 0.0
		_sprite(t, a["pos"], f, a["flip"], 1.0, roundf(bob / cell) * cell)
	for a in _crew:
		if a["type"] == "saucer":
			_draw_saucer(a)


func _draw_saucer(a: Dictionary) -> void:
	var cell := Game.CELL
	var tex: Texture2D = _tex["saucer"]
	var world := field.cell_to_world(a["pos"])
	var hover := 26.0 * cell + sin(_time * 3.0) * cell
	var origin := ((world - Vector2(tex.get_width() * cell * 0.5, hover)) / cell).floor() * cell
	if a["state"] == "beam":
		var bt: float = a["beam_t"]
		var alpha := clampf(minf(bt * 4.0, (1.5 - bt) * 4.0), 0.0, 1.0)
		var r := (a["center"] as Vector2).distance_to((a["path"] as PackedVector2Array)[0]) if (a["path"] as PackedVector2Array).size() > 0 else 10.0
		var w := r * 2.0 * cell
		var top := origin.y + tex.get_height() * cell
		for k in 4:
			var ww := w * (0.4 + 0.2 * k) * (0.9 + 0.1 * sin(_time * 20.0 + k))
			draw_rect(Rect2(Vector2(roundf((world.x - ww * 0.5) / cell) * cell, top), Vector2(roundf(ww / cell) * cell, world.y - top)), Color(0.5, 1.0, 0.85, 0.07 * alpha))
	draw_rect(Rect2(((world - Vector2(5 * cell, cell)) / cell).floor() * cell, Vector2(10 * cell, 2 * cell)), Color(0, 0, 0, 0.3))
	draw_texture_rect(tex, Rect2(origin, tex.get_size() * cell), false)


func _dither_ring(center: Vector2, radius: float, c: Color) -> void:
	var cell := Game.CELL
	var cc := (center / cell).floor()
	var r := int(radius / cell)
	for dy in range(-r, r + 1, 2):
		var span := int(sqrt(maxf(0.0, r * r - dy * dy)))
		var x := -span + (dy / 2) % 2
		while x <= span:
			draw_rect(Rect2((cc + Vector2(x, dy)) * cell, Vector2(cell, cell)), c)
			x += 2


func remove_finished_saucers() -> void:
	for i in range(_crew.size() - 1, -1, -1):
		if _crew[i].get("once", false) and _crew[i]["state"] == "rest":
			_crew.remove_at(i)
