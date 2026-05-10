extends PanelContainer
class_name TurnOrderBar

const ICON_SIZE: int = 44

var _hbox: HBoxContainer
var _entry_nodes: Array[Control] = []
var _entry_data:  Array[BotData] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 90)

	_hbox = HBoxContainer.new()
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.add_theme_constant_override("separation", 12)
	add_child(_hbox)

# Rebuild from scratch — call at battle start, round start, and after reset.
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

func update_highlight(current_index: int) -> void:
	_apply_highlight(current_index)

func _apply_highlight(current_index: int) -> void:
	for i in _entry_nodes.size():
		var bot: BotData = _entry_data[i]
		if bot.is_dead:
			_entry_nodes[i].modulate = Color(0.25, 0.25, 0.25)
		elif i == current_index:
			_entry_nodes[i].modulate = Color.WHITE
			_entry_nodes[i].scale = Vector2(1.15, 1.15)
		else:
			_entry_nodes[i].modulate = Color(0.55, 0.55, 0.55)
			_entry_nodes[i].scale = Vector2.ONE

func _make_entry(bot: BotData, is_ally: bool) -> Control:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)

	# Icon — circle for allies, diamond for enemies
	var icon := BotIcon.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.color       = bot.color
	icon.is_diamond  = not is_ally
	icon.border_color = Color(0.6, 0.85, 1.0) if is_ally else Color(1.0, 0.5, 0.5)
	icon.border_width = 2.5
	vbox.add_child(icon)

	# Short name — last segment after underscore
	var parts: PackedStringArray = bot.bot_name.split("_")
	var short_name: String = parts[parts.size() - 1]
	var label := Label.new()
	label.text = short_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(label)

	return vbox
