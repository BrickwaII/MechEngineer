extends PanelContainer
class_name BotCard

var bot_data: BotData

var _name_label: Label
var _health_bar: ProgressBar
var _hp_label: Label
var _bar_style: StyleBoxFlat
var _icon: BotIcon
var _cmd_selector: CommandSelector = null

func setup(data: BotData, icon_size: int, interactive: bool = false) -> void:
	bot_data = data

	add_theme_constant_override("margin_top",    4)
	add_theme_constant_override("margin_bottom", 4)
	add_theme_constant_override("margin_left",   6)
	add_theme_constant_override("margin_right",  6)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# Name
	_name_label = Label.new()
	_name_label.text = data.bot_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	# Row: command selector (allies) + icon side by side
	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 6)
	vbox.add_child(icon_row)

	if interactive:
		_cmd_selector = CommandSelector.new()
		icon_row.add_child(_cmd_selector)
		_cmd_selector.custom_minimum_size = Vector2(80, 80)
		_cmd_selector.set_selected(data.command)
		_cmd_selector.command_selected.connect(func(cmd: BotData.Command) -> void:
			bot_data.command = cmd
		)

	# Bot icon — circle for allies, diamond for enemies
	_icon = BotIcon.new()
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.color = data.color
	_icon.is_diamond = not interactive
	icon_row.add_child(_icon)

	# Health bar
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(80, 18)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	_health_bar.add_theme_stylebox_override("background", bg_style)

	_bar_style = StyleBoxFlat.new()
	_bar_style.bg_color = Color.GREEN
	_health_bar.add_theme_stylebox_override("fill", _bar_style)
	vbox.add_child(_health_bar)

	# HP numbers
	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_hp_label)

	update_display()

func update_display() -> void:
	if bot_data.is_dead:
		modulate = Color(0.35, 0.35, 0.35)
		_health_bar.value = 0.0
		_hp_label.text = "DESTROYED"
		return

	var pct: float = float(bot_data.current_hp) / float(bot_data.max_hp)
	_health_bar.value = pct * 100.0
	_hp_label.text = "%d / %d" % [bot_data.current_hp, bot_data.max_hp]
	_bar_style.bg_color = Color(1.0 - pct, pct, 0.0)

	# Green border when charged
	_icon.set_border(3.0 if bot_data.is_charged else 0.0)
