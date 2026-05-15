extends PanelContainer
class_name EnemyCard

signal card_clicked(enemy: EnemyData)

var enemy_data: EnemyData

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _hp_bar_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _intent_label: Label
var _preview_label: Label
var _preview_skull: Label

var _base_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat

func setup(data: EnemyData) -> void:
	enemy_data = data

	_base_style = StyleBoxFlat.new()
	_base_style.bg_color = Color(0.18, 0.08, 0.08)
	_base_style.corner_radius_top_left = 6
	_base_style.corner_radius_top_right = 6
	_base_style.corner_radius_bottom_left = 6
	_base_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", _base_style)

	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0.32, 0.12, 0.12)
	_highlight_style.border_color = Color(1.0, 0.4, 0.3)
	_highlight_style.border_width_top = 2
	_highlight_style.border_width_right = 2
	_highlight_style.border_width_bottom = 2
	_highlight_style.border_width_left = 2
	_highlight_style.corner_radius_top_left = 6
	_highlight_style.corner_radius_top_right = 6
	_highlight_style.corner_radius_bottom_left = 6
	_highlight_style.corner_radius_bottom_right = 6

	custom_minimum_size = Vector2(110, 0)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.text = data.enemy_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_name_label)

	# Colored icon circle
	var icon_size := 46
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(icon_size, icon_size)
	vbox.add_child(icon_center)

	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = Color(0.7, 0.15, 0.15)
	_icon_style.corner_radius_top_left    = icon_size / 2
	_icon_style.corner_radius_top_right   = icon_size / 2
	_icon_style.corner_radius_bottom_left = icon_size / 2
	_icon_style.corner_radius_bottom_right = icon_size / 2
	icon_panel.add_theme_stylebox_override("panel", _icon_style)
	icon_center.add_child(icon_panel)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(80, 12)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.12, 0.12)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar_style = StyleBoxFlat.new()
	_hp_bar_style.bg_color = Color(0.8, 0.2, 0.2)
	_hp_bar.add_theme_stylebox_override("fill", _hp_bar_style)
	vbox.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_hp_label)

	_intent_label = Label.new()
	_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_label.add_theme_font_size_override("font_size", 10)
	_intent_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	vbox.add_child(_intent_label)

	_preview_label = Label.new()
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.add_theme_font_size_override("font_size", 10)
	_preview_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_preview_label.visible = false
	vbox.add_child(_preview_label)

	_preview_skull = Label.new()
	_preview_skull.text = "FATAL"
	_preview_skull.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_skull.add_theme_font_size_override("font_size", 9)
	_preview_skull.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	_preview_skull.visible = false
	vbox.add_child(_preview_skull)

	update_display()

func update_display() -> void:
	if enemy_data.is_dead:
		modulate = Color(0.35, 0.35, 0.35)
		_hp_bar.value = 0.0
		_hp_label.text = "DESTROYED"
		_intent_label.text = ""
		clear_preview()
		return

	modulate = Color.WHITE
	var pct := float(enemy_data.hp) / float(enemy_data.max_hp)
	_hp_bar.value = pct * 100.0
	var r := clampf(1.0 - pct * 0.5, 0.5, 1.0)
	var g := clampf(pct * 0.4, 0.0, 0.4)
	_hp_bar_style.bg_color = Color(r, g, 0.1)
	_hp_label.text = "%d / %d" % [enemy_data.hp, enemy_data.max_hp]

	if enemy_data.current_intent:
		_intent_label.text = enemy_data.current_intent.display_label
	else:
		_intent_label.text = ""

func show_outgoing_preview(total_damage: int) -> void:
	if total_damage <= 0:
		_preview_label.visible = false
		_preview_skull.visible = false
		return
	_preview_label.text = "-%d" % total_damage
	_preview_label.visible = true
	_preview_skull.visible = total_damage >= enemy_data.hp

func clear_preview() -> void:
	_preview_label.visible = false
	_preview_skull.visible = false

func set_highlight(on: bool) -> void:
	add_theme_stylebox_override("panel", _highlight_style if on else _base_style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not enemy_data.is_dead:
		card_clicked.emit(enemy_data)
		get_viewport().set_input_as_handled()
