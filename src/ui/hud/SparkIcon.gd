extends Control
class_name SparkIcon

## 四芒星标记。with_ring = true 时外面套一圈菱形描边（卡片上的印章）。

var tint: Color = Color("#c99a3e")
var with_ring := false

func setup(c: Color, ring := false) -> void:
	tint = c
	with_ring = ring
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if with_ring:
		var d := r * 0.96
		draw_polyline(PackedVector2Array([
			Vector2(c.x, c.y - d), Vector2(c.x + d, c.y),
			Vector2(c.x, c.y + d), Vector2(c.x - d, c.y)
		]), tint, maxf(1.0, r * 0.07), true)
		_draw_star(c, r * 0.52)
	else:
		_draw_star(c, r * 0.98)

func _draw_star(c: Vector2, r: float) -> void:
	var raw := [
		[0.50, 0.03], [0.61, 0.39], [0.97, 0.50], [0.61, 0.61],
		[0.50, 0.97], [0.39, 0.61], [0.03, 0.50], [0.39, 0.39]
	]
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(c + Vector2(float(p[0]) - 0.5, float(p[1]) - 0.5) * 2.0 * r)
	draw_colored_polygon(pts, tint)
