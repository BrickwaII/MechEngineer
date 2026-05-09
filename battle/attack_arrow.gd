extends Control
class_name AttackArrow

const DURATION: float = 0.75
const ARROW_HEAD_LEN: float = 18.0
const ARROW_HEAD_WIDTH: float = 9.0
const LINE_WIDTH: float = 4.0

var _from: Vector2
var _to: Vector2
var _timer: float = 0.0

func show_attack(from: Vector2, to: Vector2) -> void:
	_from = from
	_to = to
	_timer = DURATION
	queue_redraw()

func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		queue_redraw()

func _draw() -> void:
	if _timer <= 0.0:
		return

	# Fade out over the last half of the duration
	var alpha := clampf(_timer / (DURATION * 0.5), 0.0, 1.0)
	var col := Color(1.0, 0.15, 0.15, alpha)

	draw_line(_from, _to, col, LINE_WIDTH, true)

	# Arrowhead triangle at target
	var dir := (_to - _from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var tip := _to
	var pts := PackedVector2Array([
		tip,
		tip - dir * ARROW_HEAD_LEN + perp * ARROW_HEAD_WIDTH,
		tip - dir * ARROW_HEAD_LEN - perp * ARROW_HEAD_WIDTH,
	])
	draw_colored_polygon(pts, col)
