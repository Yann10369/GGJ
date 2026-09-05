extends Control
class_name CommunityView

## Four visual stages of the neighborhood, using the existing art palette.
var level := 1

func set_harmony(value: int) -> void:
	level = 1 + mini(3, value / 25)
	queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var unit := size.x / 5.0
	for building in 5:
		var height := 56.0 + (building % 3) * 13.0
		var x := building * unit + 7
		draw_rect(Rect2(x, size.y - height, unit - 14, height), Color("#262f3a"))
		for row in 3:
			for col in 3:
				var lit := (building * 7 + row * 3 + col) % 5 < level - 1
				draw_rect(Rect2(x + 12 + col * (unit - 32) / 3, size.y - height + 9 + row * 15, 9, 7), Color("#d5ad63") if lit else Color("#39434e"))
		if level >= 2 and building % 2 == 0:
			draw_circle(Vector2(x + 19, size.y - 22), 3, Color("#c1c6b5"))
	if level >= 3:
		draw_rect(Rect2(size.x * 0.70, size.y - 19, 35, 14), Color("#87a692"))
		draw_circle(Vector2(size.x * 0.70 + 7, size.y - 4), 4, Color("#17202a"))
		draw_circle(Vector2(size.x * 0.70 + 29, size.y - 4), 4, Color("#17202a"))
	if level >= 4:
		draw_line(Vector2(24, size.y - 43), Vector2(size.x - 20, size.y - 35), Color("#a28858"), 1)
		for i in 10:
			draw_circle(Vector2(28 + i * (size.x - 55) / 10, size.y - 42 + i * 0.8), 2, Color("#ead99b"))
