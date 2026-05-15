extends PanelContainer
class_name SkillPanel

signal skill_chosen(skill: SkillData)

const CMD_ORDER: Array[String] = ["attack", "defend", "support", "charge"]
const CMD_COLORS: Dictionary = {
	"attack":  Color(0.85, 0.22, 0.18),
	"defend":  Color(0.18, 0.42, 0.88),
	"support": Color(0.18, 0.78, 0.32),
	"charge":  Color(0.88, 0.68, 0.10),
}

func populate(bot: BotData, energy_remaining: int) -> void:
	for child in get_children():
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var header := Label.new()
	header.text = bot.bot_name + " — SELECT SKILL"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 11)
	vbox.add_child(header)

	for cmd_type in CMD_ORDER:
		if not bot.skill_slots.has(cmd_type):
			continue
		var skills: Array = bot.skill_slots[cmd_type]
		if skills.is_empty():
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		vbox.add_child(row)

		for skill: SkillData in skills:
			var btn := Button.new()
			btn.text = "%s\n[%d⚡]" % [skill.skill_name, skill.energy_cost]
			btn.custom_minimum_size = Vector2(90, 40)
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.disabled = skill.energy_cost > energy_remaining

			var base_col: Color = CMD_COLORS.get(cmd_type, Color.WHITE)
			if btn.disabled:
				btn.modulate = Color(0.5, 0.5, 0.5)
			else:
				btn.modulate = Color.WHITE

			var s := skill  # capture for lambda
			btn.pressed.connect(func() -> void:
				skill_chosen.emit(s)
			)
			row.add_child(btn)
