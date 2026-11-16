class_name Overlord
extends Node2D
## The Overlord: your alien boss, bottom-left of the screen. Types out his
## lines as plain text beside him (no speech box). Anything can make him talk
## with Game.say("...").
## overlord.png is 3 frames side by side (idle, talk 1, talk 2).

const CHARS_PER_SEC := 42.0
const SCALE := 4.0

var _sprite: Sprite2D
var _label: Label
var _full := ""
var _shown := 0.0
var _hide_at := 0.0
var _time := 0.0
var _idle_at := 40.0
var _last_blip := 0
var _queue: Array = []


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/overlord.png")
	_sprite.hframes = 3
	_sprite.centered = false
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.position = Vector2(14, 720 - _sprite.texture.get_height() * SCALE - 6)
	add_child(_sprite)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(430, 0)
	_label.size = Vector2(430, 0)
	_label.add_theme_font_override("font", preload("res://assets/fonts/PixelifySans.ttf"))
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	_label.add_theme_constant_override("outline_size", 7)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.position = Vector2(108, 610)
	add_child(_label)
	Game.overlord_says.connect(say)


func say(text: String, duration := 5.0) -> void:
	# Don't cut off something he's still typing; queue one line.
	if _shown < _full.length() and _full != "":
		if _queue.size() < 2:
			_queue.append([text, duration])
		return
	_full = text
	_shown = 0.0
	_hide_at = _time + text.length() / CHARS_PER_SEC + duration
	_idle_at = _time + randf_range(45, 80)


func _process(delta: float) -> void:
	_time += delta
	if _time >= _idle_at and Game.intro_done:
		say(Quips.pick(Quips.IDLE), 5.0)
	var talking := _shown < _full.length()
	if talking:
		_shown = minf(_shown + delta * CHARS_PER_SEC, _full.length())
		var n := int(_shown)
		if n != _last_blip and n % 3 == 0:
			_last_blip = n
			Sfx.play("blip", -12.0, 0.25, 40)
	_label.text = _full.substr(0, int(_shown))
	_label.modulate.a = 1.0 if _time < _hide_at else maxf(0.0, _label.modulate.a - delta * 2.0)
	if _time >= _hide_at and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		say(next[0], next[1])
	# Keep the bottom of the text level with his head.
	_label.reset_size()
	_label.position.y = 650 - _label.size.y
	_sprite.frame = (1 + int(_time * 10.0) % 2) if talking else 0
	_sprite.position.y = 720 - _sprite.texture.get_height() * SCALE - 6 + roundf(sin(_time * 2.0) * 1.0) * SCALE
