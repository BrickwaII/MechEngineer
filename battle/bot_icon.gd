extends Control
class_name BotIcon

var color: Color = Color.WHITE
var is_diamond: bool = false
var border_color: Color = Color(0.2, 1.0, 0.3)
var border_width: float = 0.0

func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float   = minf(size.x, size.y) / 2.0

	if is_diamond:
		# Draw border diamond (slightly larger) then fill diamond on top
		if border_width > 0.0:
			var br: float = r
			var border_pts := PackedVector2Array([
				c + Vector2(0, -br), c + Vector2(br, 0),
				c + Vector2(0,  br), c + Vector2(-br, 0),
				c + Vector2(0, -br),
			])
			draw_polyline(border_pts, border_color, border_width, true)

		var fr: float = r - border_width * 0.5
		var pts := PackedVector2Array([
			c + Vector2(0, -fr), c + Vector2(fr, 0),
			c + Vector2(0,  fr), c + Vector2(-fr, 0),
		])
		draw_colored_polygon(pts, color)
	else:
		# Draw border circle then fill circle on top
		if border_width > 0.0:
			draw_circle(c, r, border_color)
		draw_circle(c, r - border_width, color)

func set_border(width: float) -> void:
	border_width = width
	queue_redraw()
