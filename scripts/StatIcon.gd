extends Control
class_name StatIcon

## 四维属性图标：心情（笑脸）/ 免疫力（盾牌）/ 物资（纸箱）/ 和睦（家）。纯 _draw 绘制。

enum Kind { MOOD, IMMUNITY, SUPPLIES, HARMONY }

var kind: Kind = Kind.MOOD
var tint: Color = Color.WHITE

static func kind_for(key: String) -> Kind:
	match key:
		"immunity": return Kind.IMMUNITY
		"supplies": return Kind.SUPPLIES
		"harmony": return Kind.HARMONY
	return Kind.MOOD

func setup(k: Kind, c: Color) -> void:
	kind = k
	tint = c
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match kind:
		Kind.IMMUNITY: _draw_shield(c, s)
		Kind.SUPPLIES: _draw_box(c, s)
		Kind.HARMONY: _draw_house(c, s)
		_: _draw_smile(c, s)

func _draw_smile(c: Vector2, s: float) -> void:
	var r := s * 0.45
	draw_arc(c, r, 0.0, TAU, 40, tint, maxf(1.0, s * 0.10))
	var er := maxf(1.0, s * 0.07)
	draw_circle(Vector2(c.x - s * 0.15, c.y - s * 0.10), er, tint)
	draw_circle(Vector2(c.x + s * 0.15, c.y - s * 0.10), er, tint)
	# 微笑弧
	var arc_r := s * 0.20
	draw_arc(Vector2(c.x, c.y + s * 0.04), arc_r, 0.55, PI - 0.55, 16, tint, maxf(1.0, s * 0.10))

func _draw_shield(c: Vector2, s: float) -> void:
	var w := s * 0.78
	var top := c.y - s * 0.46
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w * 0.5, top + s * 0.04),
		Vector2(c.x + w * 0.5, top + s * 0.04),
		Vector2(c.x + w * 0.5, top + s * 0.30),
		Vector2(c.x, top + s * 0.92),
		Vector2(c.x - w * 0.5, top + s * 0.30),
	]), tint)

func _draw_box(c: Vector2, s: float) -> void:
	var w := s * 0.86
	var h := s * 0.74
	var top := c.y - h * 0.5
	var left := c.x - w * 0.5
	# 箱身
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, top), Vector2(left + w, top),
		Vector2(left + w, top + h), Vector2(left, top + h),
	]), tint)
	# 顶部翻盖（深色）
	var dk := tint.darkened(0.28)
	draw_colored_polygon(PackedVector2Array([
		Vector2(left, top), Vector2(left + w, top),
		Vector2(left + w * 0.7, top - h * 0.28), Vector2(left + w * 0.3, top - h * 0.28),
	]), dk)
	# 中缝
	draw_line(Vector2(c.x, top - h * 0.18), Vector2(c.x, top + h), dk, maxf(1.0, s * 0.06), true)

func _draw_house(c: Vector2, s: float) -> void:
	var w := s * 0.82
	var body_h := s * 0.42
	var roof_h := s * 0.32
	var top := c.y - s * 0.46
	# 屋身
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w * 0.5, top + roof_h),
		Vector2(c.x + w * 0.5, top + roof_h),
		Vector2(c.x + w * 0.5, top + roof_h + body_h),
		Vector2(c.x - w * 0.5, top + roof_h + body_h),
	]), tint)
	# 屋顶（深色）
	var dk := tint.darkened(0.22)
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w * 0.62, top + roof_h),
		Vector2(c.x + w * 0.62, top + roof_h),
		Vector2(c.x, top),
	]), dk)
