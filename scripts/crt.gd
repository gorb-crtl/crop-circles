class_name CrtOverlay
extends CanvasLayer
## Full-screen CRT TV overlay (scanlines, colour fringing, glow, vignette,
## flicker). Purely visual: it ignores the mouse and doesn't bend the picture,
## so buttons are always exactly where they look. Strength = Game.crt_amount
## (Options slider; 0 turns it off).

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 90
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/crt.gdshader")
	_rect.material = _mat
	add_child(_rect)
	refresh()
	Game.settings_changed.connect(refresh)


func refresh() -> void:
	visible = Game.crt_amount > 0.01
	_mat.set_shader_parameter("amount", Game.crt_amount)
