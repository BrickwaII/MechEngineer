extends Control
class_name CommandSelector

signal command_selected(cmd: BotData.Command)

const _COMMANDS: Array[BotData.Command] = [
	BotData.Command.ATTACK,
	BotData.Command.DEFEND,
	BotData.Command.SUPPORT,
	BotData.Command.CHARGE,
]

const _COLORS: Dictionary = {
	BotData.Command.ATTACK:  Color(0.90, 0.22, 0.18),
	BotData.Command.DEFEND:  Color(0.18, 0.42, 0.92),
	BotData.Command.SUPPORT: Color(0.18, 0.80, 0.32),
	BotData.Command.CHARGE:  Color(0.92, 0.70, 0.10),
}

const _LABELS: Dictionary = {
	BotData.Command.ATTACK:  "ATK",
	BotData.Command.DEFEND:  "DEF",
	BotData.Command.SUPPORT: "SUP",
	BotData.Command.CHARGE:  "CHG",
}

var _selected: BotData.Command = BotData.Command.ATTACK

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(100, 100)

func set_selected(cmd: BotData.Command) -> void:
	_selected = cmd
	queue_redraw()

# ── Geometry helpers ─────────────────────────────────────────────────────────

func _diamond_center(cmd: BotData.Command) -> Vector2:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.30
	match cmd:
		BotData.Command.ATTACK:  return c + Vector2(0.0, -r)
		BotData.Command.DEFEND:  return c + Vector2(-r,  0.0)
		BotData.Command.SUPPORT: return c + Vector2( r,  0.0)
		BotData.Command.CHARGE:  return c + Vector2(0.0,  r)
	return c

func _half_size() -> float:
	return minf(size.x, size.y) * 0.22

func _diamond_pts(ctr: Vector2, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		ctr + Vector2( 0, -h),
		ctr + Vector2( h,  0),
		ctr + Vector2( 0,  h),
		ctr + Vector2(-h,  0),
	])

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	var h: float = _half_size()
	var font: Font = ThemeDB.fallback_font
	var fsize: int = 10

	for cmd in _COMMANDS:
		var ctr: Vector2 = _diamond_center(cmd)
		var pts: PackedVector2Array = _diamond_pts(ctr, h)
		var base: Color = _COLORS[cmd]
		var fill: Color = base if cmd == _selected else base.darkened(0.62)

		draw_colored_polygon(pts, fill)

		if cmd == _selected:
			var ring: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]])
			draw_polyline(ring, Color.WHITE, 1.5)

		var lbl: String = _LABELS[cmd]
		var sz: Vector2 = font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
		var tpos: Vector2 = ctr + Vector2(-sz.x * 0.5, fsize * 0.38)
		draw_string(font, tpos, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

# ── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	var h: float = _half_size()
	for cmd in _COMMANDS:
		var d: Vector2 = event.position - _diamond_center(cmd)
		if abs(d.x) + abs(d.y) <= h:
			_selected = cmd
			command_selected.emit(cmd)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
