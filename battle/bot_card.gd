extends PanelContainer
class_name BotCard

signal card_clicked(bot: BotData)
signal category_chosen(cat: String)
signal skill_or_back(result: Variant)
signal preview_result(confirmed: bool)

var bot_data: BotData

var _name_label: Label
var _health_bar: ProgressBar
var _hp_label: Label
var _stats_label: Label
var _bar_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _assignment_label: Label
var _step_panel: VBoxContainer = null

var _base_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat
var _active_style: StyleBoxFlat

func setup(data: BotData, icon_size: int, interactive: bool = false) -> void:
	bot_data = data
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL

	_base_style = StyleBoxFlat.new()
	_base_style.bg_color = Color(0.12, 0.12, 0.16)
	_base_style.corner_radius_top_left     = 6
	_base_style.corner_radius_top_right    = 6
	_base_style.corner_radius_bottom_left  = 6
	_base_style.corner_radius_bottom_right = 6
	_base_style.content_margin_top    = 6
	_base_style.content_margin_bottom = 6
	_base_style.content_margin_left   = 8
	_base_style.content_margin_right  = 8
	add_theme_stylebox_override("panel", _base_style)

	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color = Color(0.12, 0.22, 0.38)
	_highlight_style.border_color = Color(0.4, 0.8, 1.0)
	_highlight_style.border_width_top    = 2
	_highlight_style.border_width_right  = 2
	_highlight_style.border_width_bottom = 2
	_highlight_style.border_width_left   = 2
	_highlight_style.corner_radius_top_left     = 6
	_highlight_style.corner_radius_top_right    = 6
	_highlight_style.corner_radius_bottom_left  = 6
	_highlight_style.corner_radius_bottom_right = 6
	_highlight_style.content_margin_top    = 6
	_highlight_style.content_margin_bottom = 6
	_highlight_style.content_margin_left   = 8
	_highlight_style.content_margin_right  = 8

	_active_style = StyleBoxFlat.new()
	_active_style.bg_color = Color(0.22, 0.18, 0.06)
	_active_style.border_color = Color(1.0, 0.82, 0.2)
	_active_style.border_width_top    = 3
	_active_style.border_width_right  = 3
	_active_style.border_width_bottom = 3
	_active_style.border_width_left   = 3
	_active_style.corner_radius_top_left     = 6
	_active_style.corner_radius_top_right    = 6
	_active_style.corner_radius_bottom_left  = 6
	_active_style.corner_radius_bottom_right = 6
	_active_style.content_margin_top    = 6
	_active_style.content_margin_bottom = 6
	_active_style.content_margin_left   = 8
	_active_style.content_margin_right  = 8

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_name_label = Label.new()
	_name_label.text = data.bot_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_name_label)

	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(icon_size, icon_size)
	vbox.add_child(icon_center)

	var icon_panel := Panel.new()
	icon_panel.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = data.color
	_icon_style.corner_radius_top_left     = icon_size / 2
	_icon_style.corner_radius_top_right    = icon_size / 2
	_icon_style.corner_radius_bottom_left  = icon_size / 2
	_icon_style.corner_radius_bottom_right = icon_size / 2
	_icon_style.border_color = Color(0.2, 1.0, 0.3)
	icon_panel.add_theme_stylebox_override("panel", _icon_style)
	icon_center.add_child(icon_panel)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0.0
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(60, 18)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	_health_bar.add_theme_stylebox_override("background", bg_style)

	_bar_style = StyleBoxFlat.new()
	_bar_style.bg_color = Color.GREEN
	_health_bar.add_theme_stylebox_override("fill", _bar_style)
	vbox.add_child(_health_bar)

	_hp_label = Label.new()
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_hp_label)

	# Stats row: ATK · DEF · SPD
	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 10)
	_stats_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(_stats_label)

	_assignment_label = Label.new()
	_assignment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_assignment_label.add_theme_font_size_override("font_size", 10)
	_assignment_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	_assignment_label.visible = false
	vbox.add_child(_assignment_label)

	if interactive:
		_step_panel = VBoxContainer.new()
		_step_panel.add_theme_constant_override("separation", 4)
		_step_panel.visible = false
		vbox.add_child(_step_panel)

	update_display()

func show_categories() -> void:
	_clear_step_panel()
	if _step_panel == null:
		return
	_step_panel.visible = true
	var defs: Array = [
		["ATTACK",  "attack",  Color(0.90, 0.22, 0.18)],
		["DEFEND",  "defend",  Color(0.18, 0.42, 0.92)],
		["SUPPORT", "support", Color(0.18, 0.80, 0.32)],
		["CHARGE",  "charge",  Color(0.92, 0.70, 0.10)],
	]
	for d in defs:
		var btn := Button.new()
		btn.text = d[0] as String
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", d[2] as Color)
		var cat: String = d[1]
		btn.pressed.connect(func() -> void: category_chosen.emit(cat))
		_step_panel.add_child(btn)

func show_skills(skills: Array) -> void:
	_clear_step_panel()
	if _step_panel == null:
		return
	_step_panel.visible = true
	for skill: SkillData in skills:
		var btn := Button.new()
		var cost_str := "free" if skill.energy_cost == 0 else "%d⚡" % skill.energy_cost
		btn.text = "%s [%s]" % [skill.skill_name, cost_str]
		if skill.description != "":
			btn.tooltip_text = skill.description
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 28)
		btn.add_theme_font_size_override("font_size", 10)
		var s := skill
		btn.pressed.connect(func() -> void: skill_or_back.emit(s))
		_step_panel.add_child(btn)
	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: skill_or_back.emit("back"))
	_step_panel.add_child(back_btn)

func show_preview(preview_text: String) -> void:
	_clear_step_panel()
	if _step_panel == null:
		return
	_step_panel.visible = true
	var lbl := Label.new()
	lbl.text = preview_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	_step_panel.add_child(lbl)
	var confirm_btn := Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, 32)
	confirm_btn.pressed.connect(func() -> void: preview_result.emit(true))
	_step_panel.add_child(confirm_btn)
	var back_btn := Button.new()
	back_btn.text = "← Change"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void: preview_result.emit(false))
	_step_panel.add_child(back_btn)

func hide_action_ui() -> void:
	_clear_step_panel()
	if _step_panel:
		_step_panel.visible = false

func _clear_step_panel() -> void:
	if _step_panel == null:
		return
	for child in _step_panel.get_children():
		child.queue_free()

func cancel_action() -> void:
	hide_action_ui()
	category_chosen.emit("__cancel__")
	skill_or_back.emit("__cancel__")
	preview_result.emit(false)

func update_display() -> void:
	if bot_data.is_dead:
		modulate = Color(0.35, 0.35, 0.35)
		_health_bar.value = 0.0
		_hp_label.text = "DESTROYED"
		_stats_label.text = ""
		if _assignment_label:
			_assignment_label.visible = false
		return

	modulate = Color.WHITE
	var pct := float(bot_data.current_hp) / float(bot_data.max_hp)
	_health_bar.value = pct * 100.0
	_hp_label.text = "%d / %d" % [bot_data.current_hp, bot_data.max_hp]
	_bar_style.bg_color = Color(1.0 - pct, pct, 0.0)

	var atk := bot_data.attack + bot_data.temp_attack_bonus
	var def := bot_data.defense + bot_data.temp_defense_bonus
	_stats_label.text = "ATK %d  DEF %d  SPD %d" % [atk, def, bot_data.speed]

	var border_w := 3 if bot_data.charge_state.is_active() else 0
	_icon_style.border_width_top    = border_w
	_icon_style.border_width_right  = border_w
	_icon_style.border_width_bottom = border_w
	_icon_style.border_width_left   = border_w

	if _assignment_label:
		if bot_data.assigned_skill != null:
			_assignment_label.text = bot_data.assigned_skill.skill_name
			_assignment_label.visible = true
		else:
			_assignment_label.visible = false

func set_highlight(on: bool) -> void:
	add_theme_stylebox_override("panel", _highlight_style if on else _base_style)

func set_active(on: bool) -> void:
	add_theme_stylebox_override("panel", _active_style if on else _base_style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not bot_data.is_dead:
		card_clicked.emit(bot_data)
		get_viewport().set_input_as_handled()
