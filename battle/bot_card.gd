extends PanelContainer
class_name BotCard

var bot_data: BotData

var _name_label: Label
var _health_bar: ProgressBar
var _hp_label: Label
var _bar_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _cmd_selector: CommandSelector = null

func setup(data: BotData, icon_size: int, interactive: bool = false) -> void:
	bot_data = data

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Name
	_name_label = Label.new()
	_name_label.text = data.bot_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	# Colored circle icon
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(icon_size, icon_size)
	vbox.add_child(icon_center)

	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = data.color
	_icon_style.corner_radius_top_left    = icon_size / 2
	_icon_style.corner_radius_top_right   = icon_size / 2
	_icon_style.corner_radius_bottom_left = icon_size / 2
	_icon_style.corner_radius_bottom_right = icon_size / 2
	_icon_style.border_color = Color(0.2, 1.0, 0.3)
	icon_panel.add_theme_stylebox_override("panel", _icon_style)
	icon_center.add_child(icon_panel)

	# Health bar
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(80, 20)
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

	# Command selector (ally cards only)
	if interactive:
		_cmd_selector = CommandSelector.new()
		vbox.add_child(_cmd_selector)
		_cmd_selector.set_selected(data.command)
		_cmd_selector.command_selected.connect(func(cmd: BotData.Command) -> void:
			bot_data.command = cmd
		)

	update_display()

func update_display() -> void:
	if bot_data.is_dead:
		modulate = Color(0.35, 0.35, 0.35)
		_health_bar.value = 0.0
		_hp_label.text = "DESTROYED"
		return

	var pct := float(bot_data.current_hp) / float(bot_data.max_hp)
	_health_bar.value = pct * 100.0
	_hp_label.text = "%d / %d" % [bot_data.current_hp, bot_data.max_hp]
	_bar_style.bg_color = Color(1.0 - pct, pct, 0.0)

	# Green border when charged, none otherwise
	var border_w := 4 if bot_data.is_charged else 0
	_icon_style.border_width_top    = border_w
	_icon_style.border_width_right  = border_w
	_icon_style.border_width_bottom = border_w
	_icon_style.border_width_left   = border_w
