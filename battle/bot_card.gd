extends PanelContainer
class_name BotCard

signal card_clicked(bot: BotData)
signal skill_chosen(skill: SkillData)
signal preview_result(confirmed: bool)

var bot_data: BotData

var _name_label: Label
var _health_bar: ProgressBar
var _hp_label: Label
var _atb_bar: ProgressBar
var _atb_bar_style: StyleBoxFlat
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
	_base_style.content_margin_top    = 4
	_base_style.content_margin_bottom = 4
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
	_highlight_style.content_margin_top    = 4
	_highlight_style.content_margin_bottom = 4
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
	_active_style.content_margin_top    = 4
	_active_style.content_margin_bottom = 4
	_active_style.content_margin_left   = 8
	_active_style.content_margin_right  = 8

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
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
	_health_bar.custom_minimum_size = Vector2(60, 12)
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

	_atb_bar = ProgressBar.new()
	_atb_bar.min_value = 0.0
	_atb_bar.max_value = 100.0
	_atb_bar.value = 0.0
	_atb_bar.show_percentage = false
	_atb_bar.custom_minimum_size = Vector2(60, 7)
	_atb_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var atb_bg := StyleBoxFlat.new()
	atb_bg.bg_color = Color(0.08, 0.1, 0.15)
	_atb_bar.add_theme_stylebox_override("background", atb_bg)
	_atb_bar_style = StyleBoxFlat.new()
	_atb_bar_style.bg_color = Color(0.2, 0.7, 1.0)
	_atb_bar.add_theme_stylebox_override("fill", _atb_bar_style)
	vbox.add_child(_atb_bar)

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

func show_skill_accordion(skill_slots: Dictionary) -> void:
	_clear_step_panel()
	if _step_panel == null:
		return
	_step_panel.visible = true

	var cat_defs: Array = [
		["ATTACK",  "attack",  Color(0.90, 0.22, 0.18)],
		["DEFEND",  "defend",  Color(0.18, 0.42, 0.92)],
		["SUPPORT", "support", Color(0.18, 0.80, 0.32)],
		["CHARGE",  "charge",  Color(0.92, 0.70, 0.10)],
	]

	for d in cat_defs:
		var cat_key: String = d[1] as String
		var raw: Variant = skill_slots.get(cat_key, [])
		var skills: Array = raw as Array

		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 2)
		_step_panel.add_child(section)

		var header_btn := Button.new()
		header_btn.text = d[0] as String
		header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_btn.custom_minimum_size = Vector2(0, 22)
		header_btn.add_theme_font_size_override("font_size", 10)
		header_btn.add_theme_color_override("font_color", d[2] as Color)
		if skills.is_empty():
			header_btn.disabled = true
		section.add_child(header_btn)

		var skill_list := VBoxContainer.new()
		skill_list.add_theme_constant_override("separation", 2)
		skill_list.visible = false
		section.add_child(skill_list)

		var cat_color: Color = d[2] as Color
		for skill: SkillData in skills:
			var sbtn := Button.new()
			var cost_str := "free" if skill.energy_cost == 0 else "%d⚡" % skill.energy_cost
			sbtn.text = "  %s [%s]" % [skill.skill_name, cost_str]
			if skill.description != "":
				sbtn.tooltip_text = skill.description
			sbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sbtn.custom_minimum_size = Vector2(0, 18)
			sbtn.add_theme_font_size_override("font_size", 10)
			sbtn.add_theme_color_override("font_color", cat_color)
			var s := skill
			sbtn.pressed.connect(func() -> void:
				SFX.select()
				skill_chosen.emit(s)
			)
			skill_list.add_child(sbtn)

		var list := skill_list
		var step := _step_panel
		var sec  := section
		header_btn.pressed.connect(func() -> void:
			SFX.click()
			for child: Node in step.get_children():
				if child is VBoxContainer and child != sec and child.get_child_count() > 1:
					child.get_child(1).visible = false
			list.visible = not list.visible
		)

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
	confirm_btn.pressed.connect(func() -> void:
		SFX.confirm()
		preview_result.emit(true)
	)
	_step_panel.add_child(confirm_btn)
	var back_btn := Button.new()
	back_btn.text = "← Change"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		SFX.cancel_sfx()
		preview_result.emit(false)
	)
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
	skill_chosen.emit(null)
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

func update_atb(cooldown: float, max_val: float) -> void:
	if _atb_bar == null or max_val <= 0.0:
		return
	var pct := 1.0 - clampf(cooldown / max_val, 0.0, 1.0)
	_atb_bar.value = pct * 100.0
	if cooldown <= 0.0:
		_atb_bar_style.bg_color = Color(0.0, 1.0, 0.55)
	else:
		_atb_bar_style.bg_color = Color(0.2, 0.7, 1.0)

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
