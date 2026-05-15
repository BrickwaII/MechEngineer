extends Control
class_name ArrowLayer

const HEAD_LEN: float = 14.0
const HEAD_WIDTH: float = 7.0
const LINE_WIDTH: float = 3.0

# Each entry: { from, to, color, label }
var _arrows: Array = []

func clear_all() -> void:
	_arrows.clear()
	queue_redraw()

func add_arrow(from: Vector2, to: Vector2, color: Color, label: String = "") -> void:
	_arrows.append({ "from": from, "to": to, "color": color, "label": label })
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for a in _arrows:
		var f: Vector2 = a["from"]
		var t: Vector2 = a["to"]
		var col: Color = a["color"]
		var lbl: String = a["label"]

		draw_line(f, t, col, LINE_WIDTH, true)

		var dir := (t - f).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([
			t,
			t - dir * HEAD_LEN + perp * HEAD_WIDTH,
			t - dir * HEAD_LEN - perp * HEAD_WIDTH,
		])
		draw_colored_polygon(pts, col)

		if lbl != "":
			var mid := (f + t) * 0.5
			var sz := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			draw_string(font, mid - sz * 0.5, lbl,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
