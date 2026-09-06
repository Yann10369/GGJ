extends Control
class_name SuitGauge

## 扑克花色数值仪表：空心描边显示花色，内部按数值从底部向上填充（值 0 = 空，>=100 = 满）。
## 纹理：res://art/suits/suit_<suit>_line.png（描边，已带花色颜色，无需染色）
##       res://art/suits/suit_<suit>_fill.png（实心遮罩，用于裁剪填充区域）
## 映射：黑桃SPADE=免疫力 / 红桃HEART=心情 / 方块DIAMOND=物资 / 梅花CLUB=和睦

enum Suit { SPADE, HEART, DIAMOND, CLUB }

const SUIT_COLOR := {
	Suit.SPADE:   Color.WHITE,
	Suit.HEART:   Color("#e31b23"),
	Suit.DIAMOND: Color("#e31b23"),
	Suit.CLUB:    Color.WHITE,
}

const TEXTURES := {
	Suit.SPADE:   {"line": preload("res://art/suits/suit_spade_line.png"),   "mask": preload("res://art/suits/suit_spade_fill.png")},
	Suit.HEART:   {"line": preload("res://art/suits/suit_heart_line.png"),   "mask": preload("res://art/suits/suit_heart_fill.png")},
	Suit.DIAMOND: {"line": preload("res://art/suits/suit_diamond_line.png"), "mask": preload("res://art/suits/suit_diamond_fill.png")},
	Suit.CLUB:    {"line": preload("res://art/suits/suit_club_line.png"),    "mask": preload("res://art/suits/suit_club_fill.png")},
}

@export var suit: Suit = Suit.HEART:
	set(s):
		suit = s
		_apply_all()
@export var value: float = 50.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		_update_fill()
@export var line_color: Color = Color.WHITE:
	set(c):
		line_color = c
		_update_line()
@export var fill_color: Color = Color("#e74c3c"):
	set(c):
		fill_color = c
		_update_fill()

var _line: TextureRect
var _fill: TextureRect

func _ready() -> void:
	_fill = TextureRect.new()
	_fill.material = _make_material()
	_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fill)
	_line = TextureRect.new()
	_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_line.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_line)  # line 后加，显示在 fill 之上
	_apply_all()

func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _gauge_shader()
	return m

static func _gauge_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform sampler2D mask_tex;
uniform vec4 fill_color : source_color;
uniform float value;   // 0..1
void fragment() {
	vec4 m = texture(mask_tex, UV);
	if (m.a < 0.5) discard;            // 只在花色轮廓内
	if (UV.y < 1.0 - value) discard;   // 保留底部 value 比例，自底向上填充（UV.y=1 在底部）
	COLOR = fill_color;
}
"""
	return s

static func suit_for_key(key: String) -> Suit:
	match key:
		"immunity": return Suit.SPADE
		"mood": return Suit.HEART
		"supplies": return Suit.DIAMOND
		"harmony": return Suit.CLUB
	return Suit.HEART

## 设值。animate=true 时平滑过渡到目标值。
func set_value(v: float, animate := false) -> void:
	var tv := clampf(v, 0.0, 100.0)
	if animate and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "value", tv, 0.4)
	else:
		value = tv

func _apply_all() -> void:
	if _line == null or _fill == null:
		return
	line_color = Color.WHITE            # line 纹理已带花色颜色，不再染色
	fill_color = SUIT_COLOR[suit]
	var t: Dictionary = TEXTURES[suit]
	_line.texture = t["line"]
	_fill.texture = t["mask"]
	_update_fill()
	_update_line()

func _update_fill() -> void:
	if _fill == null:
		return
	_fill.material.set_shader_parameter("mask_tex", TEXTURES[suit]["mask"])
	_fill.material.set_shader_parameter("value", clampf(value, 0.0, 100.0) / 100.0)
	_fill.material.set_shader_parameter("fill_color", fill_color)

func _update_line() -> void:
	if _line == null:
		return
	# 黑桃/梅花的线稿贴图烘焙为黑色，modulate 无法提亮：用 shader 直接输出白色描边
	if suit == Suit.SPADE or suit == Suit.CLUB:
		if _line.material == null or not (_line.material is ShaderMaterial):
			var m := ShaderMaterial.new()
			m.shader = _white_line_shader()
			_line.material = m
	else:
		_line.material = null
	_line.modulate = line_color

## 把线稿贴图输出为纯白（保留 alpha 轮廓）
static func _white_line_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, tex.a);
}
"""
	return s
