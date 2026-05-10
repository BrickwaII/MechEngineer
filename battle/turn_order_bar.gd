extends PanelContainer
class_name TurnOrderBar

const CIRCLE_SIZE: int = 34

var _hbox: HBoxContainer
var _entry_nodes: Array[Control] = []
var _entry_data: Array[BotData] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 70)

	_hbox = HBoxContainer.new()
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.add_theme_constant_override("separation", 10)
	add_child(_hbox)

# Call this whenever the turn order is (re)built or after each turn.
func rebuild(turn_order: Array[BotData], allies: Array[BotData], current_index: int) -> void:
	for child in _hbox.get_children():
		child.queue_free()
	_entry_nodes.clear()
	_entry_data.clear()

	for bot in turn_order:
		var is_ally: bool = allies.has(bot)
		var entry: Control = _make_entry(bot, is_ally)
		_hbox.add_child(entry)
		_entry_nodes.append(entry)
		_entry_data.append(bot)

	_apply_highlight(current_index)

# Call after `rebuild` when only the highlight needs updating (mid-round).
func update_highlight(current_index: int) -> void:
	_apply_highlight(current_index)

func _apply_highlight(current_index: int) -> void:
	for i in _entry_nodes.size():
		var bot: BotData = _entry_data[i]
		if bot.is_dead:
			_entry_nodes[i].modulate = Color(0.28, 0.28, 0.28)
		elif i == current_index:
			_entry_nodes[i].modulate = Color.WHITE
		else:
			_entry_nodes[i].modulate = Color(0.55, 0.55, 0.55)

func _make_entry(bot: BotData, is_ally: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)

	# Colored circle
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	vbox.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(CIRCLE_SIZE, CIRCLE_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = bot.color
	style.corner_radius_top_left     = CIRCLE_SIZE / 2
	style.corner_radius_top_right    = CIRCLE_SIZE / 2
	style.corner_radius_bottom_left  = CIRCLE_SIZE / 2
	style.corner_radius_bottom_right = CIRCLE_SIZE / 2
	# Thin border to distinguish ally vs enemy
	style.border_width_top    = 2
	style.border_width_right  = 2
	style.border_width_bottom = 2
	style.border_width_left   = 2
	style.border_color = Color(0.55, 0.80, 1.0) if is_ally else Color(1.0, 0.45, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# Short name label — just the suffix after the last underscore
	var parts: PackedStringArray = bot.bot_name.split("_")
	var short_name: String = parts[parts.size() - 1]
	var label := Label.new()
	label.text = short_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(label)

	return vbox
